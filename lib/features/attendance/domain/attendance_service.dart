import 'dart:async';

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
import '../../../core/services/device_id_service.dart';
import 'offline_sync_service.dart';

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
  AttendanceService(this._db, {OfflineSyncService? syncService})
      : _syncService = syncService ?? OfflineSyncService();

  final FirebaseFirestore _db;
  final OfflineSyncService _syncService;

  Future<AttendanceScanResult> register({
    required String employeeId,
    required String employeeName,
    required CompanySettings settings,
  }) async {
    final now = DateTime.now();
    final today = now.toIso8601String().substring(0, 10);
    final docId = '$employeeId-$today';

    final connectivityResult = await Connectivity().checkConnectivity();
    final isOffline = connectivityResult.contains(ConnectivityResult.none);

    DocumentSnapshot<Map<String, dynamic>>? docSnap;
    if (!isOffline) {
      try {
        docSnap = await _db.collection('attendance').doc(docId).get();
      } catch (_) {
        // Fall back to offline check
      }
    }

    // Check local pending records to determine if checked in/out today
    final pendingRecords = await _syncService.getPendingRecords();
    final localPending = pendingRecords.firstWhere(
      (r) =>
          r['docId'] == docId ||
          (r['employeeId'] == employeeId && r['date'] == today),
      orElse: () => <String, dynamic>{},
    );

    final bool hasDocSnap = docSnap != null && docSnap.exists;
    final bool hasLocalPending = localPending.isNotEmpty;
    final bool existsToday = hasDocSnap || hasLocalPending;

    // ── Location Priority Resolution ─────────────────────────────────────────
    double effectiveLat = settings.latitude;
    double effectiveLng = settings.longitude;
    double effectiveRadius = settings.radiusMeters;

    if (!isOffline) {
      try {
        final userDoc = await _db.collection('users').doc(employeeId).get();
        if (userDoc.exists && userDoc.data() != null) {
          final userData = userDoc.data()!;
          final assignedLat =
              (userData['assignedLocationLat'] as num?)?.toDouble();
          final assignedLng =
              (userData['assignedLocationLng'] as num?)?.toDouble();
          final assignedRadius =
              (userData['assignedLocationRadius'] as num?)?.toDouble();
          if (assignedLat != null && assignedLng != null) {
            effectiveLat = assignedLat;
            effectiveLng = assignedLng;
            if (assignedRadius != null) effectiveRadius = assignedRadius;
          }
        }
      } catch (_) {}
    }

    if (!await Geolocator.isLocationServiceEnabled()) {
      throw StateError('ERR:gpsServiceRequired');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw StateError('ERR:locationPermissionDenied');
    }

    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    final distance = Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      effectiveLat,
      effectiveLng,
    );

    if (!settings.allowRemoteClockIn && distance > effectiveRadius) {
      throw StateError(
        'ERR:notInOfficePerimeter|${distance.toInt()}|${effectiveRadius.toInt()}',
      );
    }

    final currentDeviceId = await DeviceIdService.getDeviceId();

    if (!isOffline) {
      try {
        final userRef = _db.collection('users').doc(employeeId);
        final userDoc = await userRef.get();
        if (userDoc.exists && userDoc.data() != null) {
          final userData = userDoc.data()!;
          final boundDeviceId = userData['boundDeviceId'] as String?;
          if (boundDeviceId == null || boundDeviceId.isEmpty) {
            // First time registration: permanently link deviceId to account
            await userRef.set(
              {
                'boundDeviceId': currentDeviceId,
              },
              SetOptions(merge: true),
            );
          } else if (boundDeviceId != currentDeviceId) {
            // Block attendance from a different phone
            throw StateError('ERR:deviceMismatch');
          }
        }
      } catch (e) {
        if (e.toString().contains('ERR:deviceMismatch')) {
          rethrow;
        }
      }
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

    final docData = docSnap?.data();
    final hasCheckoutInDoc = docData != null && docData['checkoutTime'] != null;
    final hasCheckoutInPending = localPending.containsKey('checkoutTime') &&
        localPending['checkoutTime'] != null;

    if (existsToday) {
      if (hasCheckoutInDoc || hasCheckoutInPending) {
        throw StateError('ERR:alreadyCompletedToday');
      }

      // Check-out rule 1: Before 10:30 AM, scan is not allowed
      final isBefore1030 = now.hour < 10 || (now.hour == 10 && now.minute < 30);
      if (isBefore1030) {
        throw StateError('ERR:checkoutNotBefore1030');
      }

      final formattedCheckout = DateFormat('hh:mm a').format(now);

      if (isOffline) {
        final updatedLocal = await _syncService.updatePendingCheckout(
          employeeId: employeeId,
          todayDateStr: today,
          checkoutTimeStr: now.toIso8601String(),
          latitude: position.latitude,
          longitude: position.longitude,
          deviceModel: model,
          batteryLevel: battery,
        );

        if (!updatedLocal) {
          // If no local check-in record exists yet, create a pending checkout entry
          await _syncService.savePendingRecord({
            'id': const Uuid().v4(),
            'docId': docId,
            'employeeId': employeeId,
            'employeeName': employeeName,
            'date': today,
            'checkoutTime': now.toIso8601String(),
            'checkoutLatitude': position.latitude,
            'checkoutLongitude': position.longitude,
            'checkoutDeviceModel': model,
            'checkoutBatteryLevel': battery,
            'deviceId': currentDeviceId,
            'isCheckoutOnly': true,
            'isPendingSync': true,
          });
        }

        return AttendanceScanResult(
          type: AttendanceType.checkOut,
          recordTime: now,
          message: 'SUCCESS:checkOutOffline|$formattedCheckout',
        );
      } else {
        try {
          await _db.collection('attendance').doc(docId).update({
            'checkoutTime': now.toIso8601String(),
            'checkoutLatitude': position.latitude,
            'checkoutLongitude': position.longitude,
            'checkoutDeviceModel': model,
            'checkoutBatteryLevel': battery,
            'deviceId': currentDeviceId,
          });

          // Trigger sync for any other pending records
          unawaited(_syncService.syncPendingRecords());

          return AttendanceScanResult(
            type: AttendanceType.checkOut,
            recordTime: now,
            message: 'SUCCESS:checkOut|$formattedCheckout',
          );
        } catch (_) {
          // Fallback to offline checkout if network write fails
          await _syncService.updatePendingCheckout(
            employeeId: employeeId,
            todayDateStr: today,
            checkoutTimeStr: now.toIso8601String(),
            latitude: position.latitude,
            longitude: position.longitude,
            deviceModel: model,
            batteryLevel: battery,
          );

          return AttendanceScanResult(
            type: AttendanceType.checkOut,
            recordTime: now,
            message: 'SUCCESS:checkOutOffline|$formattedCheckout',
          );
        }
      }
    } else {
      // Check-in logic
      DateTime checkInTime;
      String status = 'present';

      final isOnTime = (now.hour == 7) || (now.hour == 8 && now.minute < 15);

      if (isOnTime) {
        checkInTime = DateTime(now.year, now.month, now.day, 7, 00);
        status = 'present';
      } else if (now.hour >= 8) {
        checkInTime = now;
        status = 'late';
      } else {
        checkInTime = now;
        status = 'present';
      }

      final recordId = const Uuid().v4();
      final recordMap = AttendanceRecord(
        id: recordId,
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
        internetStatus: isOffline ? 'offline' : 'online',
        deviceId: currentDeviceId,
      ).toJson();

      recordMap['docId'] = docId;
      recordMap['isPendingSync'] = isOffline;

      final formattedCheckIn = DateFormat('hh:mm a').format(checkInTime);

      if (isOffline) {
        await _syncService.savePendingRecord(recordMap);
        return AttendanceScanResult(
          type: AttendanceType.checkIn,
          recordTime: checkInTime,
          message: 'SUCCESS:checkInOffline|$formattedCheckIn',
        );
      } else {
        try {
          await _db.collection('attendance').doc(docId).set(recordMap);

          if (status == 'late') {
            try {
              final formattedScanTime = DateFormat('hh:mm a').format(now);
              await _db.collection('notifications').add({
                'title': 'Late Attendance Registered',
                'body':
                    '$employeeName registered attendance late at $formattedScanTime (Designated time: 08:15 AM).',
                'type': 'admin',
                'senderId': employeeId,
                'senderName': employeeName,
                'createdAt': FieldValue.serverTimestamp(),
                'readBy': <String>[],
                'deletedBy': <String>[],
              });
            } catch (_) {}
          }

          // Trigger background sync for any previous pending items
          unawaited(_syncService.syncPendingRecords());

          return AttendanceScanResult(
            type: AttendanceType.checkIn,
            recordTime: checkInTime,
            message: 'SUCCESS:checkIn|$formattedCheckIn',
          );
        } catch (_) {
          // Fallback to offline saving
          recordMap['isPendingSync'] = true;
          await _syncService.savePendingRecord(recordMap);

          return AttendanceScanResult(
            type: AttendanceType.checkIn,
            recordTime: checkInTime,
            message: 'SUCCESS:checkInOffline|$formattedCheckIn',
          );
        }
      }
    }
  }
}
