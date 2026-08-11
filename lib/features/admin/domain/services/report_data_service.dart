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

    // 2. Fetch Attendance Records – only for authorized employees.
    // Firestore 'whereIn' supports at most 30 values per query, so we batch.
    final List<Map<String, dynamic>> rawDocs = [];
    if (authorizedUserIds.isNotEmpty) {
      final idList = authorizedUserIds.toList();
      const batchSize = 30;
      for (int i = 0; i < idList.length; i += batchSize) {
        final batch = idList.sublist(
          i,
          (i + batchSize) > idList.length ? idList.length : (i + batchSize),
        );
        final snap = await _db
            .collection('attendance')
            .where('employeeId', whereIn: batch)
            .get();
        rawDocs.addAll(snap.docs.map((d) => d.data()));
      }
    }

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
    if (currentUser.isAdmin) {
      // Admins can see everyone – a full collection read is allowed by rules.
      final querySnap = await _db.collection('users').get();
      return querySnap.docs
          .map((d) => UserModel.fromJson(d.data(), d.id))
          .toList();
    } else {
      // Managers can only read users where createdBy == their UID  OR
      // managerId == their UID.  A full collection .get() would be denied by
      // Firestore rules, so we issue two filtered queries and merge.
      final byCreatedBy = await _db
          .collection('users')
          .where('createdBy', isEqualTo: currentUser.uid)
          .get();
      final byManagerId = await _db
          .collection('users')
          .where('managerId', isEqualTo: currentUser.uid)
          .get();

      // Merge and de-duplicate by document ID.
      final Map<String, UserModel> merged = {};
      for (final d in [...byCreatedBy.docs, ...byManagerId.docs]) {
        merged[d.id] = UserModel.fromJson(d.data(), d.id);
      }
      return merged.values.toList();
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
          empExpectedDays++;
          totalExpectedDays++;
        }

        if (record != null) {
          final status =
              (record['status']?.toString() ?? 'present').toLowerCase();

          DateTime? checkIn = record['time'] != null
              ? DateTime.tryParse(record['time'].toString())
              : null;
          DateTime? checkOut = record['checkoutTime'] != null
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
          if (expectedToWork && date.isBefore(DateTime.now())) {
            // Did not work when expected
            empAbsent++;
            totalAbsent++;
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
          } else {
            // Not expected to work, or future date
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
        }
      }

      double empAttRate = empExpectedDays > 0
          ? ((empPresent + empLate) / empExpectedDays) * 100
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
        ? ((totalPresent + totalLate) / totalExpectedDays) * 100
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
    // Basic schedule assumption: Weekends are off?
    // In many applications, this is customizable. We will assume Mon-Fri or Mon-Sat based on general defaults,
    // or if the app has a specific field, we can use it.
    // For now, if date is Sunday, assume off.
    if (date.weekday == DateTime.sunday) return false;
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
