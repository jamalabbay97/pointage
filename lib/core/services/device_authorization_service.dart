import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'device_id_service.dart';

enum DeviceAuthResult {
  authorized,
  registeredNewDevice,
  unauthorized,
  credentialMissing,
  error,
}

class DeviceAuthorizationService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static const _localAuthPrefix = 'app_device_authorized_v2_';
  static const _localHashPrefix = 'app_device_auth_hash_v2_';

  /// Checks if this device has been previously verified and authorized locally for this user.
  static Future<bool> isDeviceAuthorizedLocally(String uid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isAuth = prefs.getBool('$_localAuthPrefix$uid') ?? false;
      if (!isAuth) return false;

      // Also verify device ID hash matches local storage
      final storedHash = prefs.getString('$_localHashPrefix$uid');
      if (storedHash == null || storedHash.isEmpty) return isAuth;

      final currentHash = await DeviceIdentityService.getDeviceIdHash(uid);
      return storedHash == currentHash;
    } catch (_) {
      return false;
    }
  }

  /// Caches the device authorization locally so subsequent launches and offline modes are instant.
  static Future<void> saveDeviceAuthorizationLocally(
    String uid,
    String deviceIdHash,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await Future.wait([
        prefs.setBool('$_localAuthPrefix$uid', true),
        prefs.setString('$_localHashPrefix$uid', deviceIdHash),
      ]);
    } catch (e) {
      debugPrint('Error saving local device authorization: $e');
    }
  }

  /// Clears local authorization (e.g. on explicit logout or admin reset).
  static Future<void> clearDeviceAuthorizationLocally(String uid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await Future.wait([
        prefs.remove('$_localAuthPrefix$uid'),
        prefs.remove('$_localHashPrefix$uid'),
      ]);
    } catch (e) {
      debugPrint('Error clearing local device authorization: $e');
    }
  }

  /// Verifies if the current device is authorized for the given user.
  /// If no device is bound, it atomically binds this device.
  /// Uses offline-first logic: if already verified on this device, it immediately succeeds
  /// without locking the user out when offline or on slow networks.
  static Future<DeviceAuthResult> verifyOrRegisterDevice(User user) async {
    final deviceIdHash = await DeviceIdentityService.getDeviceIdHash(user.uid);
    final wasLocallyAuthorized = await isDeviceAuthorizedLocally(user.uid);

    try {
      final fingerprintHash =
          await DeviceIdentityService.getDeviceFingerprintHash();
      final metadata = await DeviceIdentityService.getDeviceMetadata();
      final userRef = _db.collection('users').doc(user.uid);

      // Run Firestore verification with a fast 3.5s timeout
      final result =
          await _db.runTransaction<DeviceAuthResult>((transaction) async {
        final snapshot = await transaction.get(userRef);

        if (!snapshot.exists || snapshot.data() == null) {
          return wasLocallyAuthorized
              ? DeviceAuthResult.authorized
              : DeviceAuthResult.error;
        }

        final data = snapshot.data()!;
        final role =
            (data['role'] as String? ?? 'employee').trim().toLowerCase();

        // Admins and Managers are not restricted to a single device
        if (role == 'admin' || role == 'manager') {
          return DeviceAuthResult.authorized;
        }

        final activeDeviceIdHash = data['activeDeviceIdHash'] as String?;
        final legacyDeviceId = data['boundDeviceId'] as String?;

        if (activeDeviceIdHash == null || activeDeviceIdHash.isEmpty) {
          if (legacyDeviceId != null && legacyDeviceId.isNotEmpty) {
            // Migration for users who already had a device bound with the legacy method
            if (legacyDeviceId == deviceIdHash ||
                legacyDeviceId ==
                    await DeviceIdentityService.getRawDeviceId(user.uid)) {
              // Legacy match, upgrade to hash
              _upgradeDeviceBinding(
                transaction,
                userRef,
                deviceIdHash,
                fingerprintHash,
                metadata,
              );
              return DeviceAuthResult.authorized;
            } else {
              // If was locally authorized on this phone, auto-upgrade
              if (wasLocallyAuthorized) {
                _upgradeDeviceBinding(
                  transaction,
                  userRef,
                  deviceIdHash,
                  fingerprintHash,
                  metadata,
                );
                return DeviceAuthResult.authorized;
              }
              return DeviceAuthResult.unauthorized;
            }
          }

          // Case A: No device registered - atomically bind this device
          _upgradeDeviceBinding(
            transaction,
            userRef,
            deviceIdHash,
            fingerprintHash,
            metadata,
          );
          return DeviceAuthResult.registeredNewDevice;
        }

        // Case B: Same device (Fast path)
        if (activeDeviceIdHash == deviceIdHash) {
          transaction.update(userRef, {
            'deviceBinding.lastVerifiedAt': FieldValue.serverTimestamp(),
            'deviceBinding.lastSeenAt': FieldValue.serverTimestamp(),
            'deviceBinding.platform': metadata['platform'],
            'deviceBinding.browser': metadata['browser'],
            'deviceBinding.appVersion': metadata['appVersion'],
            'isAutoRepair': true,
          });
          return DeviceAuthResult.authorized;
        }

        // Case C: Different device ID, let's check the Fingerprint fallback
        final activeDeviceFingerprint =
            data['activeDeviceFingerprint'] as String?;

        if (activeDeviceFingerprint != null &&
            activeDeviceFingerprint.isNotEmpty &&
            activeDeviceFingerprint == fingerprintHash) {
          // Fingerprint matches! Repair local storage
          _upgradeDeviceBinding(
            transaction,
            userRef,
            deviceIdHash,
            fingerprintHash,
            metadata,
          );
          return DeviceAuthResult.authorized;
        }

        // If locally authorized on this device and user, trust local authorization
        if (wasLocallyAuthorized) {
          return DeviceAuthResult.authorized;
        }

        // Case D: Completely different device
        return DeviceAuthResult.unauthorized;
      }).timeout(const Duration(milliseconds: 6000));

      // Cache authorization locally on success
      if (result == DeviceAuthResult.authorized ||
          result == DeviceAuthResult.registeredNewDevice) {
        await saveDeviceAuthorizationLocally(user.uid, deviceIdHash);
      } else if (result == DeviceAuthResult.unauthorized &&
          !wasLocallyAuthorized) {
        await clearDeviceAuthorizationLocally(user.uid);
      }

      // Log audit event asynchronously
      if (result == DeviceAuthResult.registeredNewDevice) {
        unawaited(_logEvent(user.uid, 'DEVICE_REGISTERED', metadata));
      } else if (result == DeviceAuthResult.authorized) {
        unawaited(_logEvent(user.uid, 'DEVICE_VERIFIED', metadata));
      } else if (result == DeviceAuthResult.unauthorized) {
        unawaited(_logEvent(user.uid, 'UNAUTHORIZED_DEVICE_ATTEMPT', metadata));
      }

      return result;
    } catch (e) {
      debugPrint('Device verification network notice/error: $e');
      // If network fails, timeout, or offline:
      // ALWAYS prioritize keeping the user signed in if previously authorized on this device!
      if (wasLocallyAuthorized) {
        return DeviceAuthResult.authorized;
      }
      return DeviceAuthResult.error;
    }
  }

  static void _upgradeDeviceBinding(
    Transaction transaction,
    DocumentReference userRef,
    String deviceIdHash,
    String fingerprintHash,
    Map<String, String> metadata,
  ) {
    transaction.update(userRef, {
      'activeDeviceIdHash': deviceIdHash,
      'activeDeviceFingerprint': fingerprintHash,
      'deviceBinding': {
        'deviceIdHash': deviceIdHash,
        'fingerprintHash': fingerprintHash,
        'status': 'active',
        'registeredAt': FieldValue.serverTimestamp(),
        'lastVerifiedAt': FieldValue.serverTimestamp(),
        'lastSeenAt': FieldValue.serverTimestamp(),
        'platform': metadata['platform'],
        'browser': metadata['browser'],
        'appVersion': metadata['appVersion'],
      },
      'isAutoRepair': true,
    });
  }

  /// Admin method to reset a user's device binding
  static Future<void> resetUserDevice(String targetUid, String adminUid) async {
    try {
      final userRef = _db.collection('users').doc(targetUid);

      await _db.runTransaction((transaction) async {
        final snapshot = await transaction.get(userRef);
        if (!snapshot.exists) return;

        transaction.update(userRef, {
          'activeDeviceIdHash': FieldValue.delete(),
          'boundDeviceId': FieldValue.delete(), // clean up legacy field too
          'deviceBinding.status': 'unregistered',
          'deviceBinding.deviceIdHash': FieldValue.delete(),
        });
      });

      await clearDeviceAuthorizationLocally(targetUid);
      _logEvent(targetUid, 'DEVICE_RESET_BY_ADMIN', {'adminUid': adminUid});
    } catch (e) {
      debugPrint('Reset device error: $e');
      rethrow;
    }
  }

  static Future<void> _logEvent(
    String uid,
    String event,
    Map<String, dynamic> extraData,
  ) async {
    try {
      await _db.collection('logs').add({
        'uid': uid,
        'event': event,
        'timestamp': FieldValue.serverTimestamp(),
        ...extraData,
      });
    } catch (_) {}
  }
}
