import 'package:cloud_firestore/cloud_firestore.dart';

/// Runtime configuration for optional backend integrations.
class AppConfig {
  const AppConfig._();

  static const adminApiBaseUrlFromEnvironment = String.fromEnvironment(
    'POINTAGE_API_BASE_URL',
  );

  /// Resolves the admin API base URL from compile-time defines first, then
  /// Firestore company settings (`settings/company.adminApiBaseUrl`).
  static Future<String> resolveAdminApiBaseUrl(FirebaseFirestore db) async {
    final fromEnvironment = adminApiBaseUrlFromEnvironment.trim();
    if (fromEnvironment.isNotEmpty) {
      return fromEnvironment;
    }

    try {
      final doc = await db.collection('settings').doc('company').get();
      final fromSettings = doc.data()?['adminApiBaseUrl'];
      if (fromSettings is String && fromSettings.trim().isNotEmpty) {
        return fromSettings.trim();
      }
    } catch (_) {
      // Fall through to empty string.
    }

    return '';
  }
}
