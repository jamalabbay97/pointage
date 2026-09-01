import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Numeric Password Validation Tests', () {
    final numericRegex = RegExp(r'^\d+$');

    test('Accepts valid numeric-only passwords', () {
      expect(numericRegex.hasMatch('123456'), isTrue);
      expect(numericRegex.hasMatch('000000'), isTrue);
      expect(numericRegex.hasMatch('9876543210'), isTrue);
    });

    test('Rejects passwords with letters or special characters', () {
      expect(numericRegex.hasMatch('12345a'), isFalse);
      expect(numericRegex.hasMatch('password'), isFalse);
      expect(numericRegex.hasMatch('123-456'), isFalse);
      expect(numericRegex.hasMatch('12345!'), isFalse);
      expect(numericRegex.hasMatch(''), isFalse);
    });
  });
}
