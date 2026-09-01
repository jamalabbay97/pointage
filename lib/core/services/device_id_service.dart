import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:universal_io/io.dart';
import 'package:uuid/uuid.dart';

class DeviceIdService {
  static const _storage = FlutterSecureStorage();
  static const _storageKey = 'app_unique_device_id';

  static Future<String> getDeviceId() async {
    try {
      if (kIsWeb) {
        return _getStoredFallbackId();
      }

      final device = DeviceInfoPlugin();

      if (Platform.isAndroid) {
        final androidInfo = await device.androidInfo;
        final id = androidInfo.id;
        if (id.isNotEmpty) return id;
      } else if (Platform.isIOS) {
        final iosInfo = await device.iosInfo;
        final id = iosInfo.identifierForVendor;
        if (id != null && id.isNotEmpty) return id;
      } else if (Platform.isWindows) {
        final winInfo = await device.windowsInfo;
        final id = winInfo.deviceId;
        if (id.isNotEmpty) return id;
      } else if (Platform.isMacOS) {
        final macInfo = await device.macOsInfo;
        final id = macInfo.systemGUID;
        if (id != null && id.isNotEmpty) return id;
      } else if (Platform.isLinux) {
        final linuxInfo = await device.linuxInfo;
        final id = linuxInfo.machineId;
        if (id != null && id.isNotEmpty) return id;
      }
    } catch (_) {
      // Fallback if platform query fails
    }

    return _getStoredFallbackId();
  }

  static Future<String> _getStoredFallbackId() async {
    try {
      final existing = await _storage.read(key: _storageKey);
      if (existing != null && existing.isNotEmpty) {
        return existing;
      }
      final newId = const Uuid().v4();
      await _storage.write(key: _storageKey, value: newId);
      return newId;
    } catch (_) {
      return const Uuid().v4();
    }
  }
}
