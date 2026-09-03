import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const _storage = FlutterSecureStorage();
const _pendingStorageKey = 'pending_offline_attendance_records_v1';

class OfflineSyncService {
  OfflineSyncService() {
    _initConnectivityListener();
  }

  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _isSyncing = false;

  void _initConnectivityListener() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen(
      (results) {
        if (!results.contains(ConnectivityResult.none)) {
          syncPendingRecords();
        }
      },
    );
  }

  void dispose() {
    _connectivitySubscription?.cancel();
  }

  /// Retrieves all pending attendance records saved locally.
  Future<List<Map<String, dynamic>>> getPendingRecords() async {
    try {
      final rawJson = await _storage.read(key: _pendingStorageKey);
      if (rawJson == null || rawJson.isEmpty) return [];
      final List decoded = jsonDecode(rawJson) as List;
      return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (e) {
      debugPrint('Error reading pending attendance records: $e');
      return [];
    }
  }

  /// Saves a new offline attendance record locally.
  Future<void> savePendingRecord(Map<String, dynamic> recordJson) async {
    try {
      final records = await getPendingRecords();
      final docId = recordJson['docId'] ??
          '${recordJson['employeeId']}-${recordJson['date']}';

      final index = records.indexWhere(
        (r) => r['docId'] == docId || r['id'] == recordJson['id'],
      );
      if (index >= 0) {
        records[index] = recordJson;
      } else {
        records.add(recordJson);
      }

      await _storage.write(
        key: _pendingStorageKey,
        value: jsonEncode(records),
      );
    } catch (e) {
      debugPrint('Error saving pending attendance record: $e');
    }
  }

  /// Updates a pending record with checkout details.
  Future<bool> updatePendingCheckout({
    required String employeeId,
    required String todayDateStr,
    required String checkoutTimeStr,
    required double latitude,
    required double longitude,
    required String deviceModel,
    required int batteryLevel,
  }) async {
    try {
      final records = await getPendingRecords();
      final docId = '$employeeId-$todayDateStr';
      final index = records.indexWhere(
        (r) =>
            r['docId'] == docId ||
            (r['employeeId'] == employeeId && r['date'] == todayDateStr),
      );

      if (index >= 0) {
        final existing = Map<String, dynamic>.from(records[index]);
        existing['checkoutTime'] = checkoutTimeStr;
        existing['checkoutLatitude'] = latitude;
        existing['checkoutLongitude'] = longitude;
        existing['checkoutDeviceModel'] = deviceModel;
        existing['checkoutBatteryLevel'] = batteryLevel;
        existing['isPendingCheckout'] = true;
        records[index] = existing;

        await _storage.write(
          key: _pendingStorageKey,
          value: jsonEncode(records),
        );
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error updating pending checkout record: $e');
      return false;
    }
  }

  /// Removes a pending record once synced to Firestore.
  Future<void> removePendingRecord(String id) async {
    try {
      final records = await getPendingRecords();
      records.removeWhere((r) => r['id'] == id || r['docId'] == id);
      await _storage.write(
        key: _pendingStorageKey,
        value: jsonEncode(records),
      );
    } catch (e) {
      debugPrint('Error removing pending record: $e');
    }
  }

  /// Uploads all pending offline attendance records to Firestore.
  Future<int> syncPendingRecords() async {
    if (_isSyncing) return 0;
    _isSyncing = true;
    int syncedCount = 0;

    try {
      final connectivity = await Connectivity().checkConnectivity();
      if (connectivity.contains(ConnectivityResult.none)) {
        _isSyncing = false;
        return 0;
      }

      final records = await getPendingRecords();
      if (records.isEmpty) {
        _isSyncing = false;
        return 0;
      }

      final db = FirebaseFirestore.instance;

      for (final record in List<Map<String, dynamic>>.from(records)) {
        final employeeId = record['employeeId'] as String?;
        final dateStr = record['date'] as String?;
        if (employeeId == null || dateStr == null) continue;

        final docId = record['docId'] as String? ?? '$employeeId-$dateStr';
        final docRef = db.collection('attendance').doc(docId);
        final docSnap = await docRef.get();

        final isCheckoutOnly = record['isCheckoutOnly'] == true;

        if (isCheckoutOnly) {
          if (docSnap.exists) {
            await docRef.update({
              'checkoutTime': record['checkoutTime'],
              'checkoutLatitude': record['checkoutLatitude'],
              'checkoutLongitude': record['checkoutLongitude'],
              'checkoutDeviceModel': record['checkoutDeviceModel'],
              'checkoutBatteryLevel': record['checkoutBatteryLevel'],
            });
          }
        } else {
          final cleanMap = Map<String, dynamic>.from(record)
            ..remove('docId')
            ..remove('isPendingSync')
            ..remove('isCheckoutOnly')
            ..remove('isPendingCheckout');

          if (!docSnap.exists) {
            await docRef.set(cleanMap);
          } else {
            // Update if checkout exists in local record
            if (record.containsKey('checkoutTime') &&
                record['checkoutTime'] != null) {
              await docRef.update({
                'checkoutTime': record['checkoutTime'],
                'checkoutLatitude': record['checkoutLatitude'],
                'checkoutLongitude': record['checkoutLongitude'],
                'checkoutDeviceModel': record['checkoutDeviceModel'],
                'checkoutBatteryLevel': record['checkoutBatteryLevel'],
              });
            }
          }

          // Auto-bind device ID to worker profile if not already set
          final recordDeviceId = record['deviceId'] as String?;
          if (recordDeviceId != null && recordDeviceId.isNotEmpty) {
            try {
              final userRef = db.collection('users').doc(employeeId);
              final userSnap = await userRef.get();
              if (userSnap.exists && userSnap.data() != null) {
                final role = (userSnap.data()!['role'] as String? ?? 'employee')
                    .trim()
                    .toLowerCase();
                if (role != 'admin' && role != 'manager') {
                  final boundDeviceId =
                      userSnap.data()!['boundDeviceId'] as String?;
                  if (boundDeviceId == null || boundDeviceId.isEmpty) {
                    await userRef.set(
                      {'boundDeviceId': recordDeviceId},
                      SetOptions(merge: true),
                    );
                  }
                }
              }
            } catch (_) {}
          }

          if (record['status'] == 'late') {
            try {
              final employeeName = record['employeeName'] ?? 'Employee';
              final timeStr = record['time'] ?? '';
              await db.collection('notifications').add({
                'title': 'Late Attendance Registered (Offline Sync)',
                'body':
                    '$employeeName registered attendance late at $timeStr (Designated time: 08:15 AM).',
                'type': 'admin',
                'senderId': employeeId,
                'senderName': employeeName,
                'createdAt': FieldValue.serverTimestamp(),
                'readBy': <String>[],
                'deletedBy': <String>[],
              });
            } catch (_) {}
          }
        }

        await removePendingRecord(record['id'] ?? docId);
        syncedCount++;
      }
    } catch (e) {
      debugPrint('Error syncing pending offline records: $e');
    } finally {
      _isSyncing = false;
    }

    return syncedCount;
  }
}

final offlineSyncServiceProvider = Provider<OfflineSyncService>((ref) {
  final service = OfflineSyncService();
  ref.onDispose(() => service.dispose());
  return service;
});

final pendingSyncCountProvider = StreamProvider<int>((ref) async* {
  final service = ref.watch(offlineSyncServiceProvider);
  while (true) {
    final records = await service.getPendingRecords();
    yield records.length;
    await Future.delayed(const Duration(seconds: 3));
  }
});
