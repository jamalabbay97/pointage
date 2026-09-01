import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const _storage = FlutterSecureStorage();

class UserSettings {
  final bool biometricEnabled;
  final bool pushNotifications;
  final bool dailyReminders;
  final bool autoSyncOffline;
  final String
      autoLockTimeout; // e.g. "1 minute", "5 minutes", "15 minutes", "Never"

  UserSettings({
    required this.biometricEnabled,
    required this.pushNotifications,
    required this.dailyReminders,
    required this.autoSyncOffline,
    required this.autoLockTimeout,
  });

  UserSettings copyWith({
    bool? biometricEnabled,
    bool? pushNotifications,
    bool? dailyReminders,
    bool? autoSyncOffline,
    String? autoLockTimeout,
  }) {
    return UserSettings(
      biometricEnabled: biometricEnabled ?? this.biometricEnabled,
      pushNotifications: pushNotifications ?? this.pushNotifications,
      dailyReminders: dailyReminders ?? this.dailyReminders,
      autoSyncOffline: autoSyncOffline ?? this.autoSyncOffline,
      autoLockTimeout: autoLockTimeout ?? this.autoLockTimeout,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'biometricEnabled': biometricEnabled,
      'pushNotifications': pushNotifications,
      'dailyReminders': dailyReminders,
      'autoSyncOffline': autoSyncOffline,
      'autoLockTimeout': autoLockTimeout,
    };
  }

  factory UserSettings.fromJson(Map<String, dynamic> json) {
    return UserSettings(
      biometricEnabled: json['biometricEnabled'] as bool? ?? true,
      pushNotifications: json['pushNotifications'] as bool? ?? true,
      dailyReminders: json['dailyReminders'] as bool? ?? true,
      autoSyncOffline: json['autoSyncOffline'] as bool? ?? true,
      autoLockTimeout: json['autoLockTimeout'] as String? ?? 'Never',
    );
  }
}

class UserSettingsNotifier extends AsyncNotifier<UserSettings> {
  @override
  Future<UserSettings> build() async {
    return _loadPreferences();
  }

  Future<UserSettings> _loadPreferences() async {
    final bio = await _storage.read(key: 'pref_biometric');
    final push = await _storage.read(key: 'pref_push');
    final daily = await _storage.read(key: 'pref_daily');
    final sync = await _storage.read(key: 'pref_sync');
    final lock = await _storage.read(key: 'pref_lock');

    UserSettings? firestoreSettings;
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('user_settings')
            .doc(user.uid)
            .get();
        if (doc.exists && doc.data() != null) {
          firestoreSettings = UserSettings.fromJson(doc.data()!);
        }
      } catch (_) {}
    }

    if (firestoreSettings != null) {
      // Keep local storage in sync
      await _storage.write(
        key: 'pref_biometric',
        value: firestoreSettings.biometricEnabled.toString(),
      );
      await _storage.write(
        key: 'pref_push',
        value: firestoreSettings.pushNotifications.toString(),
      );
      await _storage.write(
        key: 'pref_daily',
        value: firestoreSettings.dailyReminders.toString(),
      );
      await _storage.write(
        key: 'pref_sync',
        value: firestoreSettings.autoSyncOffline.toString(),
      );
      await _storage.write(
        key: 'pref_lock',
        value: firestoreSettings.autoLockTimeout,
      );
      return firestoreSettings;
    }

    return UserSettings(
      biometricEnabled: bio == null ? true : bio == 'true',
      pushNotifications: push == null ? true : push == 'true',
      dailyReminders: daily == null ? true : daily == 'true',
      autoSyncOffline: sync == null ? true : sync == 'true',
      autoLockTimeout: lock ?? 'Never',
    );
  }

  Future<void> _syncToFirestore(UserSettings newSettings) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await FirebaseFirestore.instance
            .collection('user_settings')
            .doc(user.uid)
            .set(newSettings.toJson());
      } catch (_) {}
    }
  }

  Future<void> updateBiometric(bool value) async {
    await _storage.write(key: 'pref_biometric', value: value.toString());
    if (state.hasValue) {
      final newSettings = state.value!.copyWith(biometricEnabled: value);
      state = AsyncData(newSettings);
      await _syncToFirestore(newSettings);
    }
  }

  Future<void> updatePush(bool value) async {
    await _storage.write(key: 'pref_push', value: value.toString());
    if (state.hasValue) {
      final newSettings = state.value!.copyWith(pushNotifications: value);
      state = AsyncData(newSettings);
      await _syncToFirestore(newSettings);
    }
  }

  Future<void> updateDaily(bool value) async {
    await _storage.write(key: 'pref_daily', value: value.toString());
    if (state.hasValue) {
      final newSettings = state.value!.copyWith(dailyReminders: value);
      state = AsyncData(newSettings);
      await _syncToFirestore(newSettings);
    }
  }

  Future<void> updateSync(bool value) async {
    await _storage.write(key: 'pref_sync', value: value.toString());
    if (state.hasValue) {
      final newSettings = state.value!.copyWith(autoSyncOffline: value);
      state = AsyncData(newSettings);
      await _syncToFirestore(newSettings);
    }
  }

  Future<void> updateLock(String value) async {
    await _storage.write(key: 'pref_lock', value: value);
    if (state.hasValue) {
      final newSettings = state.value!.copyWith(autoLockTimeout: value);
      state = AsyncData(newSettings);
      await _syncToFirestore(newSettings);
    }
  }
}

final userSettingsProvider =
    AsyncNotifierProvider<UserSettingsNotifier, UserSettings>(() {
  return UserSettingsNotifier();
});
