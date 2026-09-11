import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:universal_io/io.dart';
import 'package:universal_html/html.dart' as html;
import 'package:uuid/uuid.dart';

class DeviceIdentityService {
  static const _secureStorage = FlutterSecureStorage();

  /// Returns the raw device ID stored locally. Generates a new secure UUID if not present.
  static Future<String> getRawDeviceId(String userId) async {
    final storageKey = 'app_unique_device_id_$userId';

    try {
      final prefs = await SharedPreferences.getInstance();
      String? existingId;

      // 1. Try to read from SharedPreferences first (stable across web sessions)
      existingId = prefs.getString(storageKey);

      // 2. Fallback to FlutterSecureStorage
      if (existingId == null || existingId.isEmpty) {
        try {
          existingId = await _secureStorage.read(key: storageKey);
        } catch (_) {}
      }

      // 3. Fallback to Cookies on Web
      if (kIsWeb && (existingId == null || existingId.isEmpty)) {
        try {
          final cookies = html.document.cookie?.split(';') ?? [];
          for (final cookie in cookies) {
            final parts = cookie.split('=');
            if (parts.length == 2 && parts[0].trim() == storageKey) {
              existingId = parts[1].trim();
              break;
            }
          }
        } catch (_) {}
      }

      // 4. Fallback to legacy global key
      if (existingId == null || existingId.isEmpty) {
        const legacyKey = 'app_unique_device_id';
        existingId = prefs.getString(legacyKey);

        if (existingId == null || existingId.isEmpty) {
          try {
            existingId = await _secureStorage.read(key: legacyKey);
          } catch (_) {}
        }

        if (kIsWeb && (existingId == null || existingId.isEmpty)) {
          try {
            final cookies = html.document.cookie?.split(';') ?? [];
            for (final cookie in cookies) {
              final parts = cookie.split('=');
              if (parts.length == 2 && parts[0].trim() == legacyKey) {
                existingId = parts[1].trim();
                break;
              }
            }
          } catch (_) {}
        }
      }

      // If still not found, generate a new ID
      final newId = (existingId != null && existingId.isNotEmpty)
          ? existingId
          : const Uuid().v4();

      // Persist to all mechanisms to ensure it survives
      try {
        await prefs.setString(storageKey, newId);
      } catch (_) {}

      try {
        await _secureStorage.write(key: storageKey, value: newId);
      } catch (_) {}

      if (kIsWeb) {
        try {
          // Expiration of 1 year
          html.document.cookie =
              '$storageKey=$newId; max-age=31536000; path=/; samesite=strict';
        } catch (_) {}
      }

      return newId;
    } catch (_) {
      // In-memory fallback if all storage fails
      return const Uuid().v4();
    }
  }

  /// Returns the SHA-256 hash of the raw device credential for safe server-side storage and comparison.
  static Future<String> getDeviceIdHash(String userId) async {
    final rawId = await getRawDeviceId(userId);
    final bytes = utf8.encode(rawId);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Formats a human-readable device model for Web, extracting OS, phone model, and browser.
  /// Appends a short device identifier so admins can verify if the same device is being used.
  static String formatWebDeviceModel(
    WebBrowserInfo webInfo, {
    String? deviceId,
  }) {
    String os = 'Web';
    String? phoneModel;
    final ua = webInfo.userAgent ?? '';

    // Detect OS and phone model from user agent & platform
    if (ua.contains('Android')) {
      os = 'Android';
      final match = RegExp(
        r'Android\s+[^;]+;\s*(?:[a-zA-Z]{2}[-_][a-zA-Z]{2};\s*)?([^;)]+?)(?:\s+Build|[;)])',
        caseSensitive: false,
      ).firstMatch(ua);
      if (match != null) {
        final rawModel = match.group(1)?.trim();
        if (rawModel != null &&
            rawModel.isNotEmpty &&
            !rawModel.toLowerCase().contains('khtml')) {
          phoneModel = rawModel;
        }
      }
    } else if (ua.contains('iPhone') ||
        webInfo.platform?.contains('iPhone') == true) {
      os = 'iPhone';
    } else if (ua.contains('iPad') ||
        webInfo.platform?.contains('iPad') == true) {
      os = 'iPad';
    } else if (ua.contains('Windows') ||
        webInfo.platform?.contains('Win') == true) {
      os = 'Windows';
    } else if (ua.contains('Macintosh') ||
        ua.contains('Mac OS') ||
        webInfo.platform?.contains('Mac') == true) {
      os = 'macOS';
    } else if (ua.contains('Linux') ||
        webInfo.platform?.contains('Linux') == true) {
      os = 'Linux';
    } else if (webInfo.platform != null && webInfo.platform!.isNotEmpty) {
      os = webInfo.platform!;
    }

    String browser = webInfo.browserName.toString().split('.').last;
    if (browser.isNotEmpty) {
      browser = browser[0].toUpperCase() + browser.substring(1);
    }

    String deviceDescription;
    if (phoneModel != null && phoneModel.isNotEmpty) {
      deviceDescription = '$phoneModel ($browser)';
    } else if (os == 'Windows' || os == 'macOS' || os == 'Linux') {
      deviceDescription = '$os ($browser)';
    } else if (os == 'iPhone' || os == 'iPad' || os == 'Android') {
      deviceDescription = '$os ($browser)';
    } else {
      deviceDescription = '$browser on $os';
    }

    if (deviceId != null && deviceId.isNotEmpty) {
      final shortId = deviceId.length > 8 ? deviceId.substring(0, 8) : deviceId;
      return '$deviceDescription [ID: $shortId]';
    }

    return deviceDescription;
  }

  /// Extracts basic non-PII metadata about the device for audit logs and admin UI.
  static Future<Map<String, String>> getDeviceMetadata() async {
    final device = DeviceInfoPlugin();
    String platform = 'Unknown Platform';
    String browser = 'Unknown Browser';
    String appVersion =
        '1.0.0'; // You can use package_info_plus for real app version later if added

    try {
      if (kIsWeb) {
        final webInfo = await device.webBrowserInfo;
        final ua = webInfo.userAgent ?? '';
        if (ua.contains('Android')) {
          platform = 'Android';
        } else if (ua.contains('iPhone')) {
          platform = 'iOS';
        } else if (ua.contains('iPad')) {
          platform = 'iPadOS';
        } else if (ua.contains('Windows') ||
            webInfo.platform?.contains('Win') == true) {
          platform = 'Windows';
        } else if (ua.contains('Macintosh') ||
            webInfo.platform?.contains('Mac') == true) {
          platform = 'macOS';
        } else if (ua.contains('Linux') ||
            webInfo.platform?.contains('Linux') == true) {
          platform = 'Linux';
        } else {
          platform = webInfo.platform ?? 'Web';
        }

        final rawBrowser = webInfo.browserName.toString().split('.').last;
        browser = rawBrowser.isNotEmpty
            ? rawBrowser[0].toUpperCase() + rawBrowser.substring(1)
            : 'Browser';
      } else if (Platform.isAndroid) {
        final androidInfo = await device.androidInfo;
        platform = 'Android';
        browser = androidInfo.model;
      } else if (Platform.isIOS) {
        final iosInfo = await device.iosInfo;
        platform = 'iOS';
        browser = iosInfo.utsname.machine;
      } else if (Platform.isWindows) {
        platform = 'Windows';
      } else if (Platform.isMacOS) {
        platform = 'macOS';
      } else if (Platform.isLinux) {
        platform = 'Linux';
      }
    } catch (_) {
      // Ignore
    }

    return {
      'platform': platform,
      'browser': browser,
      'appVersion': appVersion,
    };
  }

  /// Generates a stable fingerprint of the device hardware and software environment.
  /// Used as a fallback authentication mechanism if local storage is cleared.
  static Future<String> getDeviceFingerprintHash() async {
    final device = DeviceInfoPlugin();
    final parts = <String>[];

    try {
      if (kIsWeb) {
        final webInfo = await device.webBrowserInfo;
        parts.addAll([
          webInfo.browserName.toString(),
          webInfo.platform ?? '',
          webInfo.language ?? '',
          webInfo.hardwareConcurrency?.toString() ?? '',
          webInfo.deviceMemory?.toString() ?? '',
          webInfo.userAgent ?? '',
        ]);
      } else if (Platform.isAndroid) {
        final androidInfo = await device.androidInfo;
        parts.addAll([
          'Android',
          androidInfo.brand,
          androidInfo.model,
          androidInfo.hardware,
          androidInfo.fingerprint,
        ]);
      } else if (Platform.isIOS) {
        final iosInfo = await device.iosInfo;
        parts.addAll([
          'iOS',
          iosInfo.model,
          iosInfo.utsname.machine,
          iosInfo.identifierForVendor ?? '',
        ]);
      }
    } catch (_) {}

    // Combine all parts into a single string
    final fingerprint = parts.join('|');

    // Hash the fingerprint
    final bytes = utf8.encode(fingerprint);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
}
