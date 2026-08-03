import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const _storage = FlutterSecureStorage();
const _themeKey = 'user_theme_mode';

/// Reads the saved theme synchronously before the app starts.
/// Call this in [main] and pass the result to [ProviderScope] overrides
/// so [themeModeProvider] never emits a second value after launch.
Future<ThemeMode> loadSavedTheme() async {
  try {
    final savedTheme = await _storage.read(key: _themeKey);
    switch (savedTheme) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  } catch (_) {
    return ThemeMode.system;
  }
}

class ThemeNotifier extends StateNotifier<ThemeMode> {
  /// [initialTheme] is pre-loaded in [main] so the provider starts with
  /// the correct value and never triggers a second build of [ChezLePointageApp].
  ThemeNotifier(super.initialTheme);

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    try {
      String modeStr;
      switch (mode) {
        case ThemeMode.light:
          modeStr = 'light';
          break;
        case ThemeMode.dark:
          modeStr = 'dark';
          break;
        case ThemeMode.system:
          modeStr = 'system';
          break;
      }
      await _storage.write(key: _themeKey, value: modeStr);
    } catch (_) {}
  }
}

final themeModeProvider = StateNotifierProvider<ThemeNotifier, ThemeMode>((ref) {
  // Default — overridden in main() with the pre-loaded value.
  return ThemeNotifier(ThemeMode.system);
});
