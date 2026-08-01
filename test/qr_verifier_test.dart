import 'dart:convert';
import 'package:chez_le_pointage/core/services/security_services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('QrVerifier Unit Tests', () {
    const secret = 'my_super_secret_test_key_123';
    const verifier = QrVerifier(secret);

    test('Verifies valid signed payload correctly', () {
      final now = DateTime.now().toUtc();
      final expiresAt = now.add(const Duration(minutes: 5)).toIso8601String();
      const nonce = 'nonce_abc_123';
      const dateStr = '2026-08-01';

      final signature = verifier.hmacSha256('$nonce|$dateStr|$expiresAt');

      final rawJson = jsonEncode({
        'nonce': nonce,
        'date': dateStr,
        'expiresAt': expiresAt,
        'signature': signature,
      });

      final result = verifier.verify(rawJson);
      expect(result, isTrue);
    });

    test('Rejects expired payload', () {
      final past = DateTime.now().toUtc().subtract(const Duration(minutes: 5)).toIso8601String();
      const nonce = 'nonce_expired';
      const dateStr = '2026-08-01';

      final signature = verifier.hmacSha256('$nonce|$dateStr|$past');

      final rawJson = jsonEncode({
        'nonce': nonce,
        'date': dateStr,
        'expiresAt': past,
        'signature': signature,
      });

      final result = verifier.verify(rawJson);
      expect(result, isFalse);
    });

    test('Rejects invalid signature tamper attempt', () {
      final expiresAt = DateTime.now().toUtc().add(const Duration(minutes: 5)).toIso8601String();

      final rawJson = jsonEncode({
        'nonce': 'nonce_tampered',
        'date': '2026-08-01',
        'expiresAt': expiresAt,
        'signature': 'fake_forged_signature_hash',
      });

      final result = verifier.verify(rawJson);
      expect(result, isFalse);
    });
  });
}
