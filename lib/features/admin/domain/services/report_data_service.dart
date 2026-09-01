import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/models/user_model.dart';
import '../models/attendance_report_model.dart';

class ReportDataService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<AttendanceReport> generateReport({
    required DateTime startDate,
    required DateTime endDate,
    String? targetEmployeeId,
    String? targetDepartment,
  }) async {
    final authUser = _auth.currentUser;
    if (authUser == null) {
      throw Exception('User is not authenticated');
    }

    final userDoc = await _db.collection('users').doc(authUser.uid).get();
    if (!userDoc.exists) {
      throw Exception('User document not found');
    }

    final currentUserModel = UserModel.fromJson(userDoc.data()!, userDoc.id);

    if (!currentUserModel.isAdminOrManager) {
      throw Exception('Unauthorized access');
    }

    // 1. Fetch Authorized Users
    List<UserModel> authorizedUsers =
        await _fetchAuthorizedUsers(currentUserModel);

    // Apply optional filters
    if (targetEmployeeId != null && targetEmployeeId.isNotEmpty) {
      authorizedUsers =
          authorizedUsers.where((u) => u.uid == targetEmployeeId).toList();
    }
    if (targetDepartment != null &&
        targetDepartment.isNotEmpty &&
        targetDepartment != 'All') {
      authorizedUsers = authorizedUsers
          .where((u) => u.department == targetDepartment)
          .toList();
    }

    final authorizedUserIds = authorizedUsers.map((u) => u.uid).toSet();

    // 2. Fetch Attendance Records within Date Range
    // Due to Firestore query limitations on 'in', we fetch by date and filter by authorized users
    final attendanceSnap = await _db
        .collection('attendance')
        .get(); // Note: Without a date index, we fetch all or filter locally.
    // Wait, let's optimize if possible.
    final rawDocs = attendanceSnap.docs.map((d) => d.data()).toList();

    List<Map<String, dynamic>> filteredRecords = [];

    final startOfDay = DateTime(startDate.year, startDate.month, startDate.day);
    final endOfDay =
        DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59, 999);

    for (final doc in rawDocs) {
      final empId = doc['employeeId'] as String? ?? '';

      // Ensure we only process authorized users
      if (!authorizedUserIds.contains(empId)) {
        continue;
      }

      final dateStr = doc['date'] as String? ?? '';
      DateTime? parsedDate;
      if (dateStr.isNotEmpty) {
        parsedDate = DateTime.tryParse(dateStr);
      } else if (doc['time'] != null) {
        parsedDate = DateTime.tryParse(doc['time'].toString());
      }

      if (parsedDate == null) continue;

      if (parsedDate.isAfter(startOfDay.subtract(const Duration(seconds: 1))) &&
          parsedDate.isBefore(endOfDay.add(const Duration(seconds: 1)))) {
        filteredRecords.add(doc);
      }
    }

    // 3. Process Data and compute statistics
    return _processReportData(
      currentUserModel,
      startOfDay,
      endOfDay,
      authorizedUsers,
      filteredRecords,
    );
  }

  Future<List<UserModel>> _fetchAuthorizedUsers(UserModel currentUser) async {
    final querySnap = await _db.collection('users').get();
    final allUsers =
        querySnap.docs.map((d) => UserModel.fromJson(d.data(), d.id)).toList();

    if (currentUser.isAdmin) {
      return allUsers; // Admins can see everyone
    } else {
      // Managers can only see employees they created or manage
      return allUsers
          .where(
            (u) =>
                u.createdBy == currentUser.uid ||
                u.managerId == currentUser.uid,
          )
          .toList();
    }
  }

  AttendanceReport _processReportData(
    UserModel generator,
    DateTime startDate,
    DateTime endDate,
    List<UserModel> users,
    List<Map<String, dynamic>> records,
  ) {
    int totalExpectedDays = 0;
    int totalPresent = 0;
    int totalLate = 0;
    int totalAbsent = 0;
    int totalDaysOff = 0;
    int totalLeaves = 0;
    int totalHolidays = 0;
    int totalIncomplete = 0;
    int totalLateMins = 0;
    double totalWorked = 0.0;

    List<EmployeeSummary> employeeSummaries = [];
    List<DetailedRecord> detailedRecords = [];

    // Pre-calculate date list
    List<DateTime> daysInRange = [];
    for (int i = 0; i <= endDate.difference(startDate).inDays; i++) {
      daysInRange.add(startDate.add(Duration(days: i)));
    }

    for (final user in users) {
      final userRecords =
          records.where((r) => r['employeeId'] == user.uid).toList();

      int empExpectedDays = 0;
      int empPresent = 0;
      int empLate = 0;
      int empAbsent = 0;
      int empDaysOff = 0;
      int empLeaves = 0;
      int empHolidays = 0;
      int empIncomplete = 0;
      int empLateMins = 0;
      double empWorked = 0.0;

      // Group records by date (YYYY-MM-DD)
      Map<String, Map<String, dynamic>> recordsByDate = {};
      for (final r in userRecords) {
        final dtStr = r['date']?.toString() ?? '';
        if (dtStr.isNotEmpty) recordsByDate[dtStr] = r;
      }

      for (final date in daysInRange) {
        final dateKey =
            '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
        final record = recordsByDate[dateKey];

        bool expectedToWork = _isExpectedToWork(user, date);
        if (expectedToWork) {
          // We don't increment empExpectedDays here, it's calculated upfront
        }

        if (record != null) {
          final status =
              (record['status']?.toString() ?? 'present').toLowerCase();

          DateTime? checkIn = (status != 'absent' && record['time'] != null)
              ? DateTime.tryParse(record['time'].toString())
              : null;
          DateTime? checkOut =
              (status != 'absent' && record['checkoutTime'] != null)
                  ? DateTime.tryParse(record['checkoutTime'].toString())
                  : null;

          int lateMins = 0;
          if (status == 'late' && checkIn != null) {
            lateMins = _calculateLateMinutes(checkIn, user.scheduleType);
          }

          double workedHrs = 0.0;
          if (checkIn != null && checkOut != null) {
            workedHrs = checkOut.difference(checkIn).inMinutes / 60.0;
          } else if (checkIn != null && checkOut == null) {
            empIncomplete++;
            totalIncomplete++;
          }

          if (status == 'present') {
            empPresent++;
            totalPresent++;
          } else if (status == 'late') {
            empLate++;
            totalLate++;
          } else if (status == 'absent') {
            empAbsent++;
            totalAbsent++;
          } else if (status == 'day_off' || status == 'day off') {
            empDaysOff++;
            totalDaysOff++;
          } else if (status == 'leave') {
            empLeaves++;
            totalLeaves++;
          } else if (status == 'holiday') {
            empHolidays++;
            totalHolidays++;
          }

          empLateMins += lateMins;
          totalLateMins += lateMins;
          empWorked += workedHrs;
          totalWorked += workedHrs;

          detailedRecords.add(
            DetailedRecord(
              date: date,
              employeeId: user.uid,
              employeeName: user.displayName,
              managerId: user.managerId ?? user.createdBy ?? '',
              managerName:
                  '', // Resolving manager names can be done by a separate map if needed
              department: user.department,
              schedule: user.scheduleType,
              expectedToWork: expectedToWork,
              checkIn: checkIn,
              checkOut: checkOut,
              status: status,
              lateMinutes: lateMins,
              workHours: workedHrs,
              device: record['deviceModel']?.toString() ?? '',
              notes: '',
            ),
          );
        } else {
          final bool is2010 = user.scheduleType == 'days_20_10';
          // For days_20_10: any past day without a record is absent — no concept
          // of "day off" since the rotating cycle can land on any day of the week.
          // For standard: only missed expected days (weekdays) count as absent.
          final bool countAsAbsent = is2010
              ? date.isBefore(DateTime.now())
              : (expectedToWork && date.isBefore(DateTime.now()));

          if (countAsAbsent) {
            detailedRecords.add(
              DetailedRecord(
                date: date,
                employeeId: user.uid,
                employeeName: user.displayName,
                managerId: user.managerId ?? user.createdBy ?? '',
                managerName: '',
                department: user.department,
                schedule: user.scheduleType,
                expectedToWork: true,
                status: 'absent',
                lateMinutes: 0,
                workHours: 0,
                device: '',
                notes: 'Missing Record',
              ),
            );
          } else if (!is2010) {
            // Standard schedule: add a not_scheduled record for weekends/future
            detailedRecords.add(
              DetailedRecord(
                date: date,
                employeeId: user.uid,
                employeeName: user.displayName,
                managerId: user.managerId ?? user.createdBy ?? '',
                managerName: '',
                department: user.department,
                schedule: user.scheduleType,
                expectedToWork: false,
                status: 'not_scheduled',
                lateMinutes: 0,
                workHours: 0,
                device: '',
                notes: '',
              ),
            );
          }
          // For days_20_10 future dates: no record is added at all.
        }
      }

      // ── Expected-days calculation ────────────────────────────────────────
      // For days_20_10 the contract is 20 working days per calendar month.
      // If an employee actually attended MORE than 20 days we raise the
      // expected-days baseline to match reality so that the absent count is
      // always ≥ 0 and the summary is self-consistent.
      if (user.scheduleType == 'days_20_10') {
        final bool isSingleMonth =
            startDate.year == endDate.year && startDate.month == endDate.month;
        if (isSingleMonth) {
          // Never let expectedDays fall below the actual attended days.
          final int attended = empPresent + empLate;
          empExpectedDays = attended > 20 ? attended : 20;
        } else {
          // Non-monthly range: every calendar day is a potential work day.
          empExpectedDays = daysInRange.length;
        }
      } else {
        empExpectedDays =
            daysInRange.where((d) => _isExpectedToWork(user, d)).length;
      }
      totalExpectedDays += empExpectedDays;

      // Absent = scheduled days not covered by any positive status.
      // Clamped to 0 so it is never negative (extra attendance days → absent 0).
      empAbsent = (empExpectedDays -
              (empPresent + empLate + empLeaves + empHolidays + empDaysOff))
          .clamp(0, empExpectedDays)
          .toInt();
      totalAbsent += empAbsent;

      // Attendance rate: cap at 100 % — working extra days is excellent but
      // should not produce a rate above 100 %.
      double empAttRate = empExpectedDays > 0
          ? (((empPresent + empLate) / empExpectedDays) * 100).clamp(0, 100)
          : 0.0;

      employeeSummaries.add(
        EmployeeSummary(
          managerName: '', // populate via map if needed
          department: user.department,
          employeeId: user.uid,
          employeeName: user.displayName,
          schedule: user.scheduleType,
          expectedWorkingDays: empExpectedDays,
          present: empPresent,
          late: empLate,
          absent: empAbsent,
          daysOff: empDaysOff,
          leaves: empLeaves,
          holidays: empHolidays,
          incomplete: empIncomplete,
          totalLateMinutes: empLateMins,
          totalWorkedHours: empWorked,
          attendanceRate: empAttRate,
        ),
      );
    }

    double globalAttRate = totalExpectedDays > 0
        ? (((totalPresent + totalLate) / totalExpectedDays) * 100).clamp(0, 100)
        : 0.0;

    return AttendanceReport(
      generatedAt: DateTime.now(),
      generatedBy: generator.displayName,
      scope: generator.isAdmin ? 'Global (All)' : 'Manager Scope',
      startDate: startDate,
      endDate: endDate,
      totalEmployees: users.length,
      expectedWorkingDays: totalExpectedDays,
      present: totalPresent,
      late: totalLate,
      absent: totalAbsent,
      daysOff: totalDaysOff,
      leaves: totalLeaves,
      holidays: totalHolidays,
      incompleteRecords: totalIncomplete,
      totalLateMinutes: totalLateMins,
      totalWorkedHours: totalWorked,
      attendanceRate: globalAttRate,
      employeeSummaries: employeeSummaries,
      detailedRecords: detailedRecords,
    );
  }

  bool _isExpectedToWork(UserModel user, DateTime date) {
    // For the 20-on/10-off rotating schedule every calendar day (including
    // weekends) is a potential work day.  The cycle does not follow a fixed
    // Mon-Fri pattern, so we never exclude any day of the week.
    if (user.scheduleType == 'days_20_10') {
      return true;
    }
    // Standard schedule: weekends are always non-working days.
    if (date.weekday == DateTime.saturday || date.weekday == DateTime.sunday) {
      return false;
    }
    return true;
  }

  int _calculateLateMinutes(DateTime checkIn, String scheduleType) {
    // Assuming 'standard' starts at 08:00 AM.
    // Assuming 'days_20_10' might have a different start time, let's use 08:00 for both.
    DateTime expectedStart =
        DateTime(checkIn.year, checkIn.month, checkIn.day, 8, 0, 0);

    // Add grace period if any (e.g. 15 mins)
    // expectedStart = expectedStart.add(Duration(minutes: 15));

    if (checkIn.isAfter(expectedStart)) {
      return checkIn.difference(expectedStart).inMinutes;
    }
    return 0;
  }
}
