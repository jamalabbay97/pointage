import 'package:chez_le_pointage/core/config/company_settings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CompanySettings Unit Tests', () {
    test('Parses from JSON correctly', () {
      final json = {
        'latitude': 34.0522,
        'longitude': -118.2437,
        'radiusMeters': 250.0,
        'qrSecret': 'custom_secret_key',
        'qrRotateIntervalSeconds': 30,
        'companyName': 'Acme Corp HQ',
        'allowRemoteClockIn': true,
      };

      final settings = CompanySettings.fromJson(json);

      expect(settings.latitude, equals(34.0522));
      expect(settings.longitude, equals(-118.2437));
      expect(settings.radiusMeters, equals(250.0));
      expect(settings.qrSecret, equals('custom_secret_key'));
      expect(settings.qrRotateIntervalSeconds, equals(30));
      expect(settings.companyName, equals('Acme Corp HQ'));
      expect(settings.allowRemoteClockIn, isTrue);
    });

    test('Uses fallback values when JSON fields missing', () {
      final settings = CompanySettings.fromJson({});

      expect(settings.latitude, equals(CompanySettings.defaultSettings.latitude));
      expect(settings.radiusMeters, equals(CompanySettings.defaultSettings.radiusMeters));
      expect(settings.qrRotateIntervalSeconds, equals(15));
    });
  });
}
