import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const _storage = FlutterSecureStorage();
const _langKey = 'user_app_language';

class AppLanguage {
  const AppLanguage({
    required this.code,
    required this.name,
    required this.flag,
  });

  final String code;
  final String name;
  final String flag;
}

const supportedLanguages = [
  AppLanguage(code: 'en', name: 'English', flag: '🇺🇸'),
  AppLanguage(code: 'fr', name: 'Français', flag: '🇫🇷'),
  AppLanguage(code: 'ar', name: 'العربية', flag: '🇲🇦'),
  AppLanguage(code: 'es', name: 'Español', flag: '🇪🇸'),
];

class LanguageNotifier extends StateNotifier<AppLanguage> {
  LanguageNotifier() : super(supportedLanguages[0]) {
    _loadLanguage();
  }

  Future<void> _loadLanguage() async {
    try {
      final savedCode = await _storage.read(key: _langKey);
      if (savedCode != null) {
        final match = supportedLanguages.firstWhere(
          (l) => l.code == savedCode,
          orElse: () => supportedLanguages[0],
        );
        state = match;
      }
    } catch (_) {}
  }

  Future<void> setLanguage(AppLanguage language) async {
    state = language;
    try {
      await _storage.write(key: _langKey, value: language.code);
    } catch (_) {}
  }
}

final languageProvider = StateNotifierProvider<LanguageNotifier, AppLanguage>((ref) {
  return LanguageNotifier();
});
