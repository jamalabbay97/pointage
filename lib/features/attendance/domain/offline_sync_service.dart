import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:universal_io/io.dart';

const _storage = FlutterSecureStorage();
const _pendingStorageKey = 'pending_offline_attendance_records_v2';
const _legacyPendingStorageKey = 'pending_offline_attendance_records_v1';

enum SyncResultStatus {
  success,
  noPendingRecords,
  deviceOffline,
  alreadyInProgress,
  authRequired,
  error,
}

class SyncResult {
  final SyncResultStatus status;
  final int syncedCount;
  final String? errorMessage;

  const SyncResult({
    required this.status,
    this.syncedCount = 0,
    this.errorMessage,
  });

  bool get isSuccess =>
      status == SyncResultStatus.success ||
      (status == SyncResultStatus.noPendingRecords && syncedCount == 0);
}

class OfflineSyncService with WidgetsBindingObserver {
  // Singleton pattern to ensure all components share the same listener and sync state
  static final OfflineSyncService _instance = OfflineSyncService._internal();
  factory OfflineSyncService() => _instance;

  OfflineSyncService._internal() {
    _initConnectivityListener();
    _initPeriodicChecker();
    try {
      WidgetsBinding.instance.addObserver(this);
    } catch (_) {}
    // Initial sync count emit
    refreshPendingCount();
  }

  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  Timer? _periodicTimer;
  bool _isSyncing = false;
  bool get isSyncing => _isSyncing;

  final StreamController<int> _pendingCountController =
      StreamController<int>.broadcast();
  Stream<int> get pendingCountStream => _pendingCountController.stream;

  void _initConnectivityListener() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen(
      (results) async {
        final hasInterface = results.any((r) => r != ConnectivityResult.none);
        if (hasInterface) {
          // Slight delay to allow IP routing / DNS resolution to settle
          await Future.delayed(const Duration(milliseconds: 600));
          syncPendingRecords();
        }
      },
    );
  }

  void _initPeriodicChecker() {
    // Check every 20 seconds; if pending records exist and network is up, auto-sync
    _periodicTimer?.cancel();
    _periodicTimer = Timer.periodic(const Duration(seconds: 20), (_) async {
      if (_isSyncing) return;
      final count = await getPendingCount();
      if (count > 0) {
        final online = await isNetworkAvailable();
        if (online) {
          await syncPendingRecords();
        }
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // App came to foreground: check and auto-sync immediately
      syncPendingRecords();
    }
  }

  void dispose() {
    _connectivitySubscription?.cancel();
    _periodicTimer?.cancel();
    try {
      WidgetsBinding.instance.removeObserver(this);
    } catch (_) {}
    _pendingCountController.close();
  }

  /// Checks whether network interface exists and reaches external hosts
  static Future<bool> isNetworkAvailable() async {
    try {
      final connectivity = await Connectivity().checkConnectivity();
      final hasInterface =
          connectivity.any((r) => r != ConnectivityResult.none);
      if (!hasInterface) return false;

      if (!kIsWeb) {
        try {
          final result = await InternetAddress.lookup('google.com')
              .timeout(const Duration(seconds: 3));
          if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
            return true;
          }
        } catch (_) {
          // Fallback check: attempt socket connection to a reliable DNS IP
          try {
            final socket = await Socket.connect(
              '8.8.8.8',
              53,
              timeout: const Duration(seconds: 2),
            );
            socket.destroy();
            return true;
          } catch (_) {
            // If DNS is blocked or behind special VPN, still trust network interface
            return hasInterface;
          }
        }
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Refreshes the pending count broadcast stream
  Future<int> refreshPendingCount() async {
    final count = await getPendingCount();
    if (!_pendingCountController.isClosed) {
      _pendingCountController.add(count);
    }
    return count;
  }

  /// Quick pending count read
  Future<int> getPendingCount() async {
    final records = await getPendingRecords();
    return records.length;
  }

  /// Retrieves all pending attendance records saved locally with fallback across storage layers.
  Future<List<Map<String, dynamic>>> getPendingRecords() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? rawJson = prefs.getString(_pendingStorageKey);

      // Fallback 1: FlutterSecureStorage
      if (rawJson == null || rawJson.isEmpty) {
        try {
          rawJson = await _storage.read(key: _pendingStorageKey);
        } catch (_) {}
      }

      // Fallback 2: Legacy storage key
      if (rawJson == null || rawJson.isEmpty) {
        try {
          rawJson = await _storage.read(key: _legacyPendingStorageKey);
        } catch (_) {}
      }

      if (rawJson == null || rawJson.isEmpty) return [];
      final List decoded = jsonDecode(rawJson) as List;
      return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (e) {
      debugPrint('Error reading pending attendance records: $e');
      return [];
    }
  }

  /// Saves a new offline attendance record locally to both SharedPreferences and SecureStorage.
  Future<void> savePendingRecord(Map<String, dynamic> recordJson) async {
    try {
      final records = await getPendingRecords();
      final docId = recordJson['docId'] ??
          '${recordJson['employeeId']}-${recordJson['date']}';

      final index = records.indexWhere(
        (r) =>
            r['docId'] == docId ||
            r['id'] == recordJson['id'] ||
            ('${r['employeeId']}-${r['date']}' == docId),
      );
      if (index >= 0) {
        records[index] = recordJson;
      } else {
        records.add(recordJson);
      }

      final encoded = jsonEncode(records);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_pendingStorageKey, encoded);

      try {
        await _storage.write(
          key: _pendingStorageKey,
          value: encoded,
        );
      } catch (_) {}

      await refreshPendingCount();

      // Proactively check if internet is available and auto-sync immediately
      unawaited(syncPendingRecords());
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

        final encoded = jsonEncode(records);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_pendingStorageKey, encoded);

        try {
          await _storage.write(
            key: _pendingStorageKey,
            value: encoded,
          );
        } catch (_) {}

        await refreshPendingCount();

        // Trigger background sync
        unawaited(syncPendingRecords());
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error updating pending checkout record: $e');
      return false;
    }
  }

  /// Removes a pending record once synced to Firestore.
  Future<void> removePendingRecord(
    String docId, {
    String? id,
    String? employeeId,
    String? date,
  }) async {
    try {
      final records = await getPendingRecords();
      records.removeWhere((r) {
        final rDocId = r['docId'] as String?;
        final rId = r['id'] as String?;
        final rEmpId = r['employeeId'] as String?;
        final rDate = r['date'] as String?;
        final rKey = '$rEmpId-$rDate';

        return rDocId == docId ||
            rKey == docId ||
            (id != null && (rId == id || rDocId == id)) ||
            (employeeId != null &&
                date != null &&
                rEmpId == employeeId &&
                rDate == date);
      });

      final encoded = jsonEncode(records);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_pendingStorageKey, encoded);

      try {
        await _storage.write(
          key: _pendingStorageKey,
          value: encoded,
        );
      } catch (_) {}

      await refreshPendingCount();
    } catch (e) {
      debugPrint('Error removing pending record: $e');
    }
  }

  /// Uploads all pending offline attendance records to Firestore.
  Future<SyncResult> syncPendingRecords({bool isManual = false}) async {
    if (_isSyncing) {
      return const SyncResult(status: SyncResultStatus.alreadyInProgress);
    }
    _isSyncing = true;
    int syncedCount = 0;

    try {
      final records = await getPendingRecords();
      if (records.isEmpty) {
        _isSyncing = false;
        await refreshPendingCount();
        return const SyncResult(
          status: SyncResultStatus.noPendingRecords,
          syncedCount: 0,
        );
      }

      final isOnline = await isNetworkAvailable();
      if (!isOnline) {
        _isSyncing = false;
        return const SyncResult(status: SyncResultStatus.deviceOffline);
      }

      // Ensure valid Firebase Authentication session
      var authUser = FirebaseAuth.instance.currentUser;
      if (authUser == null) {
        try {
          final savedEmail = await _storage.read(key: 'email');
          final savedPassword = await _storage.read(key: 'password');
          if (savedEmail != null &&
              savedEmail.isNotEmpty &&
              savedPassword != null &&
              savedPassword.isNotEmpty) {
            final cred = await FirebaseAuth.instance
                .signInWithEmailAndPassword(
                  email: savedEmail.trim(),
                  password: savedPassword,
                )
                .timeout(const Duration(seconds: 10));
            authUser = cred.user;
          }
        } catch (e) {
          debugPrint('Sync: Auto-reauth attempt failed: $e');
        }
      }

      if (authUser == null) {
        _isSyncing = false;
        return const SyncResult(status: SyncResultStatus.authRequired);
      } else {
        // Refresh token to prevent permission-denied errors
        try {
          await authUser.getIdToken(false).timeout(const Duration(seconds: 5));
        } catch (_) {}
      }

      final db = FirebaseFirestore.instance;

      for (final record in List<Map<String, dynamic>>.from(records)) {
        final employeeId = (record['employeeId'] as String?)?.isNotEmpty == true
            ? record['employeeId'] as String
            : authUser.uid;
        final dateStr = record['date'] as String?;
        if (dateStr == null || dateStr.isEmpty) {
          // Remove malformed record so sync is not stuck forever
          await removePendingRecord(record['id'] ?? '');
          continue;
        }

        // Always key by employeeId-dateStr to strictly guarantee NO duplicate attendance documents
        final docId = '$employeeId-$dateStr';
        final docRef = db.collection('attendance').doc(docId);

        final isCheckoutOnly = record['isCheckoutOnly'] == true;

        if (isCheckoutOnly) {
          await docRef.set(
            {
              'checkoutTime': record['checkoutTime'],
              'checkoutLatitude': record['checkoutLatitude'],
              'checkoutLongitude': record['checkoutLongitude'],
              'checkoutDeviceModel': record['checkoutDeviceModel'],
              'checkoutBatteryLevel': record['checkoutBatteryLevel'],
              'internetStatus': 'synced',
            },
            SetOptions(merge: true),
          ).timeout(const Duration(seconds: 12));
        } else {
          final cleanMap = Map<String, dynamic>.from(record)
            ..remove('docId')
            ..remove('isPendingSync')
            ..remove('isCheckoutOnly')
            ..remove('isPendingCheckout');

          cleanMap['internetStatus'] = 'synced';

          // If checkout was not performed locally, remove null checkout keys so merge: true
          // does not accidentally overwrite an existing checkout on the server
          if (cleanMap['checkoutTime'] == null) {
            cleanMap.remove('checkoutTime');
            cleanMap.remove('checkoutLatitude');
            cleanMap.remove('checkoutLongitude');
            cleanMap.remove('checkoutDeviceModel');
            cleanMap.remove('checkoutBatteryLevel');
          }

          // Atomic merge guarantees document exists and merges changes cleanly
          await docRef
              .set(cleanMap, SetOptions(merge: true))
              .timeout(const Duration(seconds: 12));

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
              }).timeout(const Duration(seconds: 6));
            } catch (_) {}
          }
        }

        // Successfully written to Firestore: remove from local storage
        await removePendingRecord(
          docId,
          id: record['id'] as String?,
          employeeId: employeeId,
          date: dateStr,
        );
        syncedCount++;
      }

      await refreshPendingCount();

      return SyncResult(
        status: SyncResultStatus.success,
        syncedCount: syncedCount,
      );
    } catch (e) {
      debugPrint('Error syncing pending offline records: $e');
      return SyncResult(
        status: SyncResultStatus.error,
        syncedCount: syncedCount,
        errorMessage: e.toString(),
      );
    } finally {
      _isSyncing = false;
      await refreshPendingCount();
    }
  }
}

final offlineSyncServiceProvider = Provider<OfflineSyncService>((ref) {
  final service = OfflineSyncService();
  ref.onDispose(() => service.dispose());
  return service;
});

final pendingSyncCountProvider = StreamProvider<int>((ref) async* {
  final service = ref.watch(offlineSyncServiceProvider);
  // Yield initial count immediately
  yield await service.getPendingCount();
  // Listen to live reactive updates
  yield* service.pendingCountStream;
});
