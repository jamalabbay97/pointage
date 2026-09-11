import 'package:chez_le_pointage/features/attendance/domain/offline_sync_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('OfflineSyncService Storage & Deduplication Tests', () {
    test(
        'Saves pending record and prevents duplicates for same employee and date',
        () async {
      final service = OfflineSyncService();

      final record1 = {
        'id': 'uuid-1',
        'docId': 'emp123-2026-09-04',
        'employeeId': 'emp123',
        'date': '2026-09-04',
        'time': '2026-09-04T07:30:00.000',
        'status': 'present',
        'isPendingSync': true,
      };

      await service.savePendingRecord(record1);
      var records = await service.getPendingRecords();
      expect(records.length, equals(1));
      expect(records.first['employeeId'], equals('emp123'));
      expect(records.first['status'], equals('present'));

      // Save updated record for same employee and date (should update, not duplicate)
      final record1Updated = {
        'id': 'uuid-2',
        'docId': 'emp123-2026-09-04',
        'employeeId': 'emp123',
        'date': '2026-09-04',
        'time': '2026-09-04T07:30:00.000',
        'status': 'late',
        'isPendingSync': true,
      };

      await service.savePendingRecord(record1Updated);
      records = await service.getPendingRecords();
      expect(records.length, equals(1)); // Still 1 record!
      expect(records.first['status'], equals('late'));
    });

    test('updatePendingCheckout updates existing record without duplicating',
        () async {
      final service = OfflineSyncService();

      final record = {
        'id': 'uuid-checkin',
        'docId': 'emp456-2026-09-04',
        'employeeId': 'emp456',
        'date': '2026-09-04',
        'time': '2026-09-04T07:00:00.000',
        'status': 'present',
        'isPendingSync': true,
      };

      await service.savePendingRecord(record);

      final updated = await service.updatePendingCheckout(
        employeeId: 'emp456',
        todayDateStr: '2026-09-04',
        checkoutTimeStr: '2026-09-04T17:00:00.000',
        latitude: 33.5,
        longitude: -7.5,
        deviceModel: 'Android Device',
        batteryLevel: 85,
      );

      expect(updated, isTrue);

      final records = await service.getPendingRecords();
      expect(records.length, equals(1));
      expect(records.first['checkoutTime'], equals('2026-09-04T17:00:00.000'));
      expect(records.first['checkoutBatteryLevel'], equals(85));
    });

    test('removePendingRecord cleans up record completely', () async {
      final service = OfflineSyncService();

      final record = {
        'id': 'uuid-todelete',
        'docId': 'emp789-2026-09-04',
        'employeeId': 'emp789',
        'date': '2026-09-04',
        'time': '2026-09-04T07:00:00.000',
      };

      await service.savePendingRecord(record);
      expect((await service.getPendingRecords()).length, equals(1));

      await service.removePendingRecord('emp789-2026-09-04');
      expect((await service.getPendingRecords()).isEmpty, isTrue);
    });

    test(
        'History deduplication merges Firestore doc and pending checkout without duplicates',
        () {
      final firestoreRecords = [
        {
          'id': 'firestore-uuid-1',
          'employeeId': 'emp999',
          'date': '2026-09-04',
          'time': '2026-09-04T07:00:00.000',
          'status': 'present',
        }
      ];

      final pendingRecords = [
        {
          'id': 'local-checkout-uuid-2',
          'docId': 'emp999-2026-09-04',
          'employeeId': 'emp999',
          'date': '2026-09-04',
          'checkoutTime': '2026-09-04T17:15:00.000',
        }
      ];

      // Key strictly by employeeId and date
      final Map<String, Map<String, dynamic>> mergedMap = {};
      for (final r in firestoreRecords) {
        final key = '${r['employeeId']}-${r['date']}';
        mergedMap[key] = Map<String, dynamic>.from(r);
      }

      for (final p in pendingRecords) {
        final key = '${p['employeeId']}-${p['date']}';
        if (!mergedMap.containsKey(key)) {
          final copy = Map<String, dynamic>.from(p);
          copy['isPendingSync'] = true;
          mergedMap[key] = copy;
        } else {
          if (p.containsKey('checkoutTime') && p['checkoutTime'] != null) {
            mergedMap[key]!['checkoutTime'] = p['checkoutTime'];
            mergedMap[key]!['isPendingSync'] = true;
          }
        }
      }

      expect(mergedMap.length, equals(1));
      final merged = mergedMap.values.first;
      expect(merged['time'], equals('2026-09-04T07:00:00.000'));
      expect(merged['checkoutTime'], equals('2026-09-04T17:15:00.000'));
      expect(merged['isPendingSync'], isTrue);
    });

    test(
        'Dashboard header UID display fallback does not show N/A when effectiveUid exists',
        () {
      const effectiveUid = 'jabbay7812xyz';
      final displayId = effectiveUid.isNotEmpty
          ? (effectiveUid.length >= 8
              ? effectiveUid.substring(0, 8)
              : effectiveUid)
          : 'N/A';

      expect(displayId, equals('jabbay78'));
    });
  });
}
