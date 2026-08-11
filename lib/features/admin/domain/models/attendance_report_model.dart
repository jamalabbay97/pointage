class AttendanceReport {
  final DateTime generatedAt;
  final String generatedBy; // User Name
  final String scope;
  final DateTime startDate;
  final DateTime endDate;

  final int totalEmployees;
  final int expectedWorkingDays;
  final int present;
  final int late;
  final int absent;
  final int daysOff;
  final int leaves;
  final int holidays;
  final int incompleteRecords;

  final int totalLateMinutes;
  final double totalWorkedHours;
  final double attendanceRate;

  final List<EmployeeSummary> employeeSummaries;
  final List<DetailedRecord> detailedRecords;

  AttendanceReport({
    required this.generatedAt,
    required this.generatedBy,
    required this.scope,
    required this.startDate,
    required this.endDate,
    required this.totalEmployees,
    required this.expectedWorkingDays,
    required this.present,
    required this.late,
    required this.absent,
    required this.daysOff,
    required this.leaves,
    required this.holidays,
    required this.incompleteRecords,
    required this.totalLateMinutes,
    required this.totalWorkedHours,
    required this.attendanceRate,
    required this.employeeSummaries,
    required this.detailedRecords,
  });
}

class EmployeeSummary {
  final String managerName;
  final String department;
  final String employeeId;
  final String employeeName;
  final String schedule;
  final int expectedWorkingDays;
  final int present;
  final int late;
  final int absent;
  final int daysOff;
  final int leaves;
  final int holidays;
  final int incomplete;
  final int totalLateMinutes;
  final double totalWorkedHours;
  final double attendanceRate;

  EmployeeSummary({
    required this.managerName,
    required this.department,
    required this.employeeId,
    required this.employeeName,
    required this.schedule,
    required this.expectedWorkingDays,
    required this.present,
    required this.late,
    required this.absent,
    required this.daysOff,
    required this.leaves,
    required this.holidays,
    required this.incomplete,
    required this.totalLateMinutes,
    required this.totalWorkedHours,
    required this.attendanceRate,
  });
}

class DetailedRecord {
  final DateTime date;
  final String employeeId;
  final String employeeName;
  final String managerId;
  final String managerName;
  final String department;
  final String schedule;
  final bool expectedToWork;
  final DateTime? checkIn;
  final DateTime? checkOut;
  final String status;
  final int lateMinutes;
  final double workHours;
  final String device;
  final String notes;

  DetailedRecord({
    required this.date,
    required this.employeeId,
    required this.employeeName,
    required this.managerId,
    required this.managerName,
    required this.department,
    required this.schedule,
    required this.expectedToWork,
    this.checkIn,
    this.checkOut,
    required this.status,
    required this.lateMinutes,
    required this.workHours,
    required this.device,
    required this.notes,
  });
}
