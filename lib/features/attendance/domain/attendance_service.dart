import 'package:battery_plus/battery_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:universal_io/io.dart';
import 'package:uuid/uuid.dart';

import '../../../core/config/company_settings.dart';
import '../../../core/models/attendance_record.dart';

enum AttendanceType { checkIn, checkOut }

class AttendanceScanResult {
  final AttendanceType type;
  final DateTime recordTime;
  final String message;

  const AttendanceScanResult({
    required this.type,
    required this.recordTime,
    required this.message,
  });
}

class AttendanceService {
  AttendanceService(this._db);
  final FirebaseFirestore _db;

  Future<AttendanceScanResult> register({
    required String employeeId,
    required String employeeName,
    required CompanySettings settings,
  }) async {
    final now = DateTime.now();
    final today = now.toIso8601String().substring(0, 10);
    final docId = '$employeeId-$today';
    final doc = _db.collection('attendance').doc(docId);
    final docSnap = await doc.get();

    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult.contains(ConnectivityResult.none)) {
      throw StateError(
        'Internet connection is required for attendance registration.',
      );
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
      throw StateError(
        'Location permission is required for attendance verification.',
      );
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

    if (docSnap.exists) {
      final existingData = docSnap.data();
      if (existingData != null && existingData['checkoutTime'] != null) {
        throw StateError(
          'You have already completed your check-in and check-out for today.',
        );
      }

      // Check-out rule 1: Before 11:00 AM, scan is not allowed
      if (now.hour < 11) {
        throw StateError(
          'Check-out is not allowed before 11:00 AM. Employees must work at least half a day before checking out.',
        );
      }

      // Check-out rule 2: At or after 11:00 AM, record actual scan time
      await doc.update({
        'checkoutTime': now.toIso8601String(),
        'checkoutLatitude': position.latitude,
        'checkoutLongitude': position.longitude,
        'checkoutDeviceModel': model,
        'checkoutBatteryLevel': battery,
      });

      final formattedCheckout = DateFormat('hh:mm a').format(now);
      return AttendanceScanResult(
        type: AttendanceType.checkOut,
        recordTime: now,
        message: 'Check-out successfully registered at $formattedCheckout!',
      );
    } else {
      // Check-in logic:
      // Rule 1: Between 7:00 AM and 8:00 AM -> record as 7:10 AM
      // Rule 2: After 8:00 AM -> record actual scan time
      DateTime checkInTime;
      String status = 'present';

      // 7:00 AM to 8:00 AM inclusive (e.g. 07:00:00 to 08:00:00)
      final is7to8AM = (now.hour == 7) ||
          (now.hour == 8 && now.minute == 0 && now.second == 0);

      if (is7to8AM) {
        checkInTime = DateTime(now.year, now.month, now.day, 7, 10);
        status = 'present';
      } else if (now.hour >= 8) {
        checkInTime = now;
        status = 'late';
      } else {
        checkInTime = now;
        status = 'present';
      }

      await doc.set(
        AttendanceRecord(
          id: const Uuid().v4(),
          employeeId: employeeId,
          employeeName: employeeName,
          date: now,
          time: checkInTime,
          checkoutTime: null,
          status: status,
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

      final formattedCheckIn = DateFormat('hh:mm a').format(checkInTime);
      return AttendanceScanResult(
        type: AttendanceType.checkIn,
        recordTime: checkInTime,
        message: 'Check-in successfully registered at $formattedCheckIn!',
      );
    }
  }
}
