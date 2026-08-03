import 'package:battery_plus/battery_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:universal_io/io.dart';
import 'package:uuid/uuid.dart';

import '../../../core/config/company_settings.dart';
import '../../../core/models/attendance_record.dart';

class AttendanceService {
  AttendanceService(this._db);
  final FirebaseFirestore _db;

  Future<void> register({
    required String employeeId,
    required String employeeName,
    required CompanySettings settings,
  }) async {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final docId = '$employeeId-$today';
    final doc = _db.collection('attendance').doc(docId);
    if ((await doc.get()).exists) {
      throw StateError('You have already checked in today.');
    }
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult.contains(ConnectivityResult.none)) {
      throw StateError('Internet connection is required for attendance registration.');
    }

    if (!await Geolocator.isLocationServiceEnabled()) {
      throw StateError('GPS location service must be enabled on your device.');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw StateError('Location permission is required for attendance verification.');
    }

    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    final distance = Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      settings.latitude,
      settings.longitude,
    );

    // Honor allowRemoteClockIn setting from admin system settings
    if (!settings.allowRemoteClockIn && distance > settings.radiusMeters) {
      throw StateError(
        'You are outside the allowed office attendance perimeter (${distance.toInt()}m from HQ, allowed limit is ${settings.radiusMeters.toInt()}m).',
      );
    }

    final device = DeviceInfoPlugin();
    String model = 'Mobile Device';
    try {
      if (kIsWeb) {
        model = 'Web Browser';
      } else if (Platform.isAndroid) {
        model = (await device.androidInfo).model;
      } else if (Platform.isIOS) {
        model = (await device.iosInfo).utsname.machine;
      } else if (Platform.isWindows) {
        model = (await device.windowsInfo).computerName;
      } else if (Platform.isMacOS) {
        model = (await device.macOsInfo).model;
      } else if (Platform.isLinux) {
        model = (await device.linuxInfo).name;
      }
    } catch (_) {
      model = 'Enterprise Client';
    }

    int battery = 100;
    try {
      battery = await Battery().batteryLevel;
    } catch (_) {
      battery = 100;
    }

    final now = DateTime.now();
    await doc.set(
      AttendanceRecord(
        id: const Uuid().v4(),
        employeeId: employeeId,
        employeeName: employeeName,
        date: now,
        time: now,
        status: 'present',
        latitude: position.latitude,
        longitude: position.longitude,
        locationAccuracy: position.accuracy,
        deviceModel: model,
        operatingSystem: kIsWeb ? 'Web' : Platform.operatingSystem,
        batteryLevel: battery,
        internetStatus: 'online',
        deviceId: const Uuid().v5(Namespace.url.value, model),
      ).toJson(),
    );
  }
}
