import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/models/user_model.dart';
import '../../../core/services/device_authorization_service.dart';

const _authStorage = FlutterSecureStorage();
const _userProfileStorageKey = 'cached_user_model_v1';

final authStateProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

final deviceAuthStatusProvider = FutureProvider<DeviceAuthResult?>((ref) async {
  final authUser = ref.watch(authStateProvider).valueOrNull;
  if (authUser == null) return null;
  return await DeviceAuthorizationService.verifyOrRegisterDevice(authUser);
});

final currentUserModelProvider = StreamProvider<UserModel?>((ref) {
  final authUser = ref.watch(authStateProvider).valueOrNull ??
      FirebaseAuth.instance.currentUser;
  if (authUser == null) return Stream.value(null);

  final defaultUser = UserModel(
    uid: authUser.uid,
    email: authUser.email ?? '',
    displayName:
        authUser.displayName ?? (authUser.email?.split('@').first ?? 'User'),
    role: 'employee',
    status: 'active',
    department: 'General',
  );

  return FirebaseFirestore.instance
      .collection('users')
      .doc(authUser.uid)
      .snapshots()
      .asyncMap<UserModel?>((snapshot) async {
    if (!snapshot.exists || snapshot.data() == null) {
      final cached = await _loadCachedUserModel(authUser.uid);
      return cached ?? defaultUser;
    }
    final model = UserModel.fromJson(snapshot.data()!, snapshot.id);
    await _cacheUserModel(model);
    return model;
  }).handleError((error, stackTrace) async {
    debugPrint('Error fetching user doc: $error');
    final cached = await _loadCachedUserModel(authUser.uid);
    return cached ?? defaultUser;
  });
});

Future<void> _cacheUserModel(UserModel model) async {
  try {
    await _authStorage.write(
      key: '${_userProfileStorageKey}_${model.uid}',
      value: jsonEncode(model.toJson()),
    );
  } catch (e) {
    debugPrint('Error caching user model: $e');
  }
}

Future<UserModel?> _loadCachedUserModel(String uid) async {
  try {
    final raw = await _authStorage.read(key: '${_userProfileStorageKey}_$uid');
    if (raw == null || raw.isEmpty) return null;
    final Map<String, dynamic> json = jsonDecode(raw);
    return UserModel.fromJson(json, uid);
  } catch (e) {
    debugPrint('Error loading cached user model: $e');
    return null;
  }
}

final isAdminOrManagerProvider = Provider<bool>((ref) {
  final userModel = ref.watch(currentUserModelProvider).valueOrNull;
  return userModel?.isAdminOrManager ?? false;
});
