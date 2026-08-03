import 'dart:convert';
import 'package:universal_io/io.dart';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

class SecureVault {
  const SecureVault(this._storage);
  final FlutterSecureStorage _storage;
  Future<void> saveToken(String token) =>
      _storage.write(key: 'jwt', value: token);
  Future<String?> readToken() => _storage.read(key: 'jwt');
  Future<void> clear() => _storage.deleteAll();
}

class BiometricGate {
  final LocalAuthentication _auth = LocalAuthentication();
  Future<bool> unlock() async {
    if (kIsWeb) return false;
    return _auth.authenticate(localizedReason: 'Unlock Chez Le Pointage securely');
  }
}

class DeviceIntegrityService {
  bool get isProbablyCompromised =>
      Platform.environment.containsKey('FRIDA') ||
      Platform.environment.containsKey('MAGISK');
  bool get isDebugged => false;
}

class QrVerifier {
  const QrVerifier(this.secret);
  final String secret;

  bool verify(String rawPayload) {
    final payload = jsonDecode(rawPayload) as Map<String, dynamic>;
    final expiresAt = DateTime.parse(payload['expiresAt'] as String);
    if (DateTime.now().toUtc().isAfter(expiresAt.toUtc())) return false;
    final nonce = payload['nonce'] as String;
    final signature = payload['signature'] as String;
    final expected = hmacSha256(
      '$nonce|${payload['date']}|${payload['expiresAt']}',
    );
    return signature == expected;
  }

  String hmacSha256(String value) =>
      Hmac(sha256, utf8.encode(secret)).convert(utf8.encode(value)).toString();
}
