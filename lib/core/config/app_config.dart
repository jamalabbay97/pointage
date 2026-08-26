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
      return _sanitizeUrl(fromEnvironment);
    }

    try {
      final doc = await db.collection('settings').doc('company').get();
      final fromSettings = doc.data()?['adminApiBaseUrl'];
      if (fromSettings is String && fromSettings.trim().isNotEmpty) {
        return _sanitizeUrl(fromSettings);
      }
    } catch (_) {
      // Fall through to default URL.
    }

    return _sanitizeUrl('https://pointage-api-zrot.onrender.com');
  }

  static String _sanitizeUrl(String url) {
    var trimmed = url.trim();
    while (trimmed.endsWith('/')) {
      trimmed = trimmed.substring(0, trimmed.length - 1);
    }
    return trimmed;
  }
}

