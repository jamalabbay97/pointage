import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/models/user_model.dart';
import '../../../core/services/device_authorization_service.dart';

const _authStorage = FlutterSecureStorage();
const _userProfileStorageKey = 'cached_user_model_v1';
const _sessionActiveKey = 'app_persistent_session_active';
const _sessionUidKey = 'app_persistent_session_uid';
const _sessionEmailKey = 'app_persistent_session_email';
const _sessionRoleKey = 'app_persistent_session_role';
const _sessionNameKey = 'app_persistent_session_display_name';

/// Tracks Firebase Auth state changes
final authStateProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

/// Verifies device authorization status with local caching
final deviceAuthStatusProvider = FutureProvider<DeviceAuthResult?>((ref) async {
  final authUser = ref.watch(authStateProvider).valueOrNull ??
      FirebaseAuth.instance.currentUser;
  if (authUser == null) {
    // Check if there is a persistent local session
    final localUid = await getPersistentSessionUid();
    if (localUid == null) return null;
    final isAuthorized =
        await DeviceAuthorizationService.isDeviceAuthorizedLocally(localUid);
    return isAuthorized ? DeviceAuthResult.authorized : null;
  }
  return await DeviceAuthorizationService.verifyOrRegisterDevice(authUser);
});

/// Provides the current UserModel, resilient across offline states and app restarts
final currentUserModelProvider = StreamProvider<UserModel?>((ref) async* {
  final authUser = ref.watch(authStateProvider).valueOrNull ??
      FirebaseAuth.instance.currentUser;

  final String? targetUid = authUser?.uid ?? await getPersistentSessionUid();

  if (targetUid == null) {
    yield null;
    return;
  }

  // 1. Immediately yield cached user model if available (Zero wait time on startup / offline)
  final cached = await _loadCachedUserModel(targetUid);
  if (cached != null) {
    yield cached;
  } else if (authUser != null) {
    yield UserModel(
      uid: authUser.uid,
      email: authUser.email ?? '',
      displayName:
          authUser.displayName ?? (authUser.email?.split('@').first ?? 'User'),
      role: 'employee',
      status: 'active',
      department: 'General',
    );
  }

  // 2. Stream live updates from Firestore if authenticated
  if (authUser != null) {
    yield* FirebaseFirestore.instance
        .collection('users')
        .doc(targetUid)
        .snapshots()
        .asyncMap<UserModel?>((snapshot) async {
      if (!snapshot.exists || snapshot.data() == null) {
        final local = await _loadCachedUserModel(targetUid);
        return local;
      }
      UserModel model = UserModel.fromJson(snapshot.data()!, snapshot.id);
      if (model.isEmployee) {
        final mgrId = model.managerId ?? model.createdBy;
        if (mgrId != null && mgrId.isNotEmpty) {
          try {
            final mgrDoc = await FirebaseFirestore.instance
                .collection('users')
                .doc(mgrId)
                .get()
                .timeout(const Duration(milliseconds: 1500));
            if (mgrDoc.exists && mgrDoc.data() != null) {
              final mgrSchedule = mgrDoc.data()!['scheduleType'] as String?;
              if (mgrSchedule != null &&
                  mgrSchedule.isNotEmpty &&
                  mgrSchedule != model.scheduleType) {
                model = model.copyWith(scheduleType: mgrSchedule);
              }
            }
          } catch (_) {}
        }
      }
      await saveUserSessionLocally(model);
      return model;
    }).handleError((error, stackTrace) async {
      debugPrint('Offline/Error fetching user doc: $error');
      final local = await _loadCachedUserModel(targetUid);
      return local;
    });
  }
});

/// Checks whether a user is permanently signed in on this device
Future<bool> isUserPermanentlyLoggedIn() async {
  if (FirebaseAuth.instance.currentUser != null) return true;
  try {
    final prefs = await SharedPreferences.getInstance();
    final isActive = prefs.getBool(_sessionActiveKey) ?? false;
    final uid = prefs.getString(_sessionUidKey);
    return isActive && uid != null && uid.isNotEmpty;
  } catch (_) {
    return false;
  }
}

/// Synchronous check if memory/cache knows session is active
bool isUserLoggedInLocallySync() {
  return FirebaseAuth.instance.currentUser != null;
}

/// Returns the UID of the permanently signed in user
Future<String?> getPersistentSessionUid() async {
  if (FirebaseAuth.instance.currentUser != null) {
    return FirebaseAuth.instance.currentUser!.uid;
  }
  try {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_sessionUidKey);
  } catch (_) {
    return null;
  }
}

/// Persists user session and profile to SharedPreferences & FlutterSecureStorage
Future<void> saveUserSessionLocally(UserModel model) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = jsonEncode(
      model.toJson(),
      toEncodable: (nonEncodable) {
        if (nonEncodable is Timestamp) {
          return nonEncodable.toDate().toIso8601String();
        }
        if (nonEncodable is DateTime) {
          return nonEncodable.toIso8601String();
        }
        return nonEncodable.toString();
      },
    );

    await Future.wait([
      prefs.setBool(_sessionActiveKey, true),
      prefs.setString(_sessionUidKey, model.uid),
      prefs.setString(_sessionEmailKey, model.email),
      prefs.setString(_sessionNameKey, model.displayName),
      prefs.setString(_sessionRoleKey, model.role),
      prefs.setString('${_userProfileStorageKey}_${model.uid}', jsonStr),
    ]);

    try {
      await _authStorage.write(
        key: '${_userProfileStorageKey}_${model.uid}',
        value: jsonStr,
      );
    } catch (_) {}
  } catch (e) {
    debugPrint('Error saving user session locally: $e');
  }
}

/// Loads cached user model from SharedPreferences first, then FlutterSecureStorage
Future<UserModel?> _loadCachedUserModel(String uid) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    String? raw = prefs.getString('${_userProfileStorageKey}_$uid');

    if (raw == null || raw.isEmpty) {
      try {
        raw = await _authStorage.read(key: '${_userProfileStorageKey}_$uid');
      } catch (_) {}
    }

    if (raw == null || raw.isEmpty) return null;
    final Map<String, dynamic> json = jsonDecode(raw);
    return UserModel.fromJson(json, uid);
  } catch (e) {
    debugPrint('Error loading cached user model: $e');
    return null;
  }
}

/// Clears persistent local session only upon explicit user logout
Future<void> clearUserSessionLocally() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final uid = prefs.getString(_sessionUidKey);

    await Future.wait([
      prefs.remove(_sessionActiveKey),
      prefs.remove(_sessionUidKey),
      prefs.remove(_sessionEmailKey),
      prefs.remove(_sessionNameKey),
      prefs.remove(_sessionRoleKey),
      if (uid != null) prefs.remove('${_userProfileStorageKey}_$uid'),
    ]);

    if (uid != null) {
      try {
        await _authStorage.delete(key: '${_userProfileStorageKey}_$uid');
      } catch (_) {}
    }
  } catch (e) {
    debugPrint('Error clearing user session: $e');
  }
}

/// Explicit sign-out triggered by the user in Settings or Profile
Future<void> performExplicitSignOut([WidgetRef? ref]) async {
  try {
    final user = FirebaseAuth.instance.currentUser;
    final uid = user?.uid ?? await getPersistentSessionUid();

    // Clear local session first
    await clearUserSessionLocally();

    // Clear device authorization cache for this user
    if (uid != null) {
      await DeviceAuthorizationService.clearDeviceAuthorizationLocally(uid);
    }

    // Sign out of Firebase Auth
    await FirebaseAuth.instance.signOut();
  } catch (e) {
    debugPrint('Error during explicit sign out: $e');
    // Ensure Firebase signOut still happens
    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {}
  }
}

final isAdminOrManagerProvider = Provider<bool>((ref) {
  final userModel = ref.watch(currentUserModelProvider).valueOrNull;
  return userModel?.isAdminOrManager ?? false;
});
