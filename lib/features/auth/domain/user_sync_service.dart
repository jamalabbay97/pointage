import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/services/device_authorization_service.dart';
import '../../../core/utils/async_timeout.dart';

enum UserSyncResult {
  success,
  disabled,
  unauthorizedDevice,
  credentialMissing,
  failed,
}

/// Ensures the Firestore user profile exists and is up to date after sign-in.
Future<UserSyncResult> syncUserAfterLogin(User user) async {
  try {
    final userDocRef =
        FirebaseFirestore.instance.collection('users').doc(user.uid);
    final doc = await withTimeout(
      userDocRef.get(),
      duration: const Duration(seconds: 20),
      label: 'Profile lookup timed out',
    );

    if (!doc.exists) {
      final isAdmin = user.email?.toLowerCase().contains('admin') ?? false;
      await withTimeout(
        userDocRef.set({
          'uid': user.uid,
          'email': user.email ?? '',
          'displayName':
              user.displayName ?? (user.email?.split('@').first ?? 'User'),
          'role': isAdmin ? 'admin' : 'employee',
          'status': 'active',
          'department': isAdmin ? 'Management' : 'Engineering',
          'createdAt': DateTime.now().toIso8601String(),
          'lastLogin': DateTime.now().toIso8601String(),
        }),
        duration: const Duration(seconds: 20),
        label: 'Profile creation timed out',
      );
      return UserSyncResult.success;
    }

    final data = doc.data() as Map<String, dynamic>;
    final status = (data['status'] as String? ?? 'active').toLowerCase();
    if (status == 'disabled') {
      return UserSyncResult.disabled;
    }

    // 2. Perform Device Authorization Check
    final deviceAuthResult =
        await DeviceAuthorizationService.verifyOrRegisterDevice(user);

    if (deviceAuthResult == DeviceAuthResult.unauthorized) {
      return UserSyncResult.unauthorizedDevice;
    } else if (deviceAuthResult == DeviceAuthResult.credentialMissing) {
      return UserSyncResult.credentialMissing;
    } else if (deviceAuthResult == DeviceAuthResult.error) {
      return UserSyncResult.failed;
    }

    // 3. Update last login timestamp if authorized
    await withTimeout(
      userDocRef.update({
        'lastLogin': DateTime.now().toIso8601String(),
      }),
      duration: const Duration(seconds: 20),
      label: 'Profile update timed out',
    );
    return UserSyncResult.success;
  } catch (_) {
    return UserSyncResult.failed;
  }
}
