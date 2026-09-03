import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

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

  /// Verifies if the current device is authorized for the given user.
  /// If no device is bound, it atomically binds this device.
  static Future<DeviceAuthResult> verifyOrRegisterDevice(User user) async {
    try {
      final deviceIdHash =
          await DeviceIdentityService.getDeviceIdHash(user.uid);
      final fingerprintHash =
          await DeviceIdentityService.getDeviceFingerprintHash();
      final metadata = await DeviceIdentityService.getDeviceMetadata();
      final userRef = _db.collection('users').doc(user.uid);

      final result =
          await _db.runTransaction<DeviceAuthResult>((transaction) async {
        final snapshot = await transaction.get(userRef);

        if (!snapshot.exists || snapshot.data() == null) {
          // Profile doesn't exist yet, we can't register a device on a non-existent user.
          // The user_sync_service will create the profile, so this should not happen if called after.
          return DeviceAuthResult.error;
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
          });
          return DeviceAuthResult.authorized;
        }

        // Case C: Different device ID, let's check the Fingerprint fallback
        final activeDeviceFingerprint =
            data['activeDeviceFingerprint'] as String?;

        if (activeDeviceFingerprint != null &&
            activeDeviceFingerprint.isNotEmpty &&
            activeDeviceFingerprint == fingerprintHash) {
          // The fingerprint perfectly matches! The user likely cleared their local storage.
          // We will repair their local storage by updating the activeDeviceIdHash to the new one.
          _upgradeDeviceBinding(
            transaction,
            userRef,
            deviceIdHash,
            fingerprintHash,
            metadata,
          );
          return DeviceAuthResult.authorized;
        }

        // Case D: Completely different device
        return DeviceAuthResult.unauthorized;
      });

      // Log event
      if (result == DeviceAuthResult.registeredNewDevice) {
        _logEvent(user.uid, 'DEVICE_REGISTERED', metadata);
      } else if (result == DeviceAuthResult.authorized) {
        _logEvent(user.uid, 'DEVICE_VERIFIED', metadata);
      } else if (result == DeviceAuthResult.unauthorized) {
        _logEvent(user.uid, 'UNAUTHORIZED_DEVICE_ATTEMPT', metadata);
      }

      return result;
    } catch (e) {
      debugPrint('Device verification error: $e');
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
