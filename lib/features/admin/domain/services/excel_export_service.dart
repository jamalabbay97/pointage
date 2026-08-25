import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import '../models/attendance_report_model.dart';
import '../../../../core/services/app_translations.dart';

class ExcelExportService {
  Uint8List generateExcel(AttendanceReport report, String langCode) {
    final excel = Excel.createExcel();
    excel.rename('Sheet1', AppTranslations.text(langCode, 'xlsSheetSummary'));

    _buildExecutiveSummary(excel, report, langCode);
    _buildEmployeesOverview(excel, report, langCode);
    _buildDetailedAttendance(excel, report, langCode);

    return Uint8List.fromList(excel.encode() ?? []);
  }

  void _buildExecutiveSummary(
    Excel excel,
    AttendanceReport report,
    String langCode,
  ) {
    final sheet = excel[AppTranslations.text(langCode, 'xlsSheetSummary')];

    // Add Report Title
    sheet.appendRow(
      [TextCellValue(AppTranslations.text(langCode, 'xlsReportTitle'))],
    );

    final dateFormat = DateFormat('yyyy-MM-dd');
    final timeFormat = DateFormat('yyyy-MM-dd HH:mm');

    sheet.appendRow([TextCellValue('')]);
    sheet.appendRow([
      TextCellValue(AppTranslations.text(langCode, 'xlsReportingPeriod')),
      TextCellValue(
        '${dateFormat.format(report.startDate)} - ${dateFormat.format(report.endDate)}',
      ),
    ]);
    sheet.appendRow([
      TextCellValue(AppTranslations.text(langCode, 'xlsScope')),
      TextCellValue(report.scope),
    ]);
    sheet.appendRow([
      TextCellValue(AppTranslations.text(langCode, 'xlsGeneratedDateTime')),
      TextCellValue(timeFormat.format(report.generatedAt)),
    ]);
    sheet.appendRow(
      [
        TextCellValue(AppTranslations.text(langCode, 'xlsGeneratedBy')),
        TextCellValue(report.generatedBy),
      ],
    );
    sheet.appendRow([TextCellValue('')]);

    sheet.appendRow([
      TextCellValue(AppTranslations.text(langCode, 'xlsTotalEmployees')),
      IntCellValue(report.totalEmployees),
    ]);
    sheet.appendRow([
      TextCellValue(AppTranslations.text(langCode, 'xlsExpectedWorkingDays')),
      IntCellValue(report.expectedWorkingDays),
    ]);
    sheet.appendRow([
      TextCellValue(AppTranslations.text(langCode, 'xlsAttendanceRecords')),
      IntCellValue(report.present + report.late),
    ]);
    sheet.appendRow([
      TextCellValue(AppTranslations.text(langCode, 'xlsPresent')),
      IntCellValue(report.present),
    ]);
    sheet.appendRow([
      TextCellValue(AppTranslations.text(langCode, 'xlsLate')),
      IntCellValue(report.late),
    ]);
    sheet.appendRow([
      TextCellValue(AppTranslations.text(langCode, 'xlsAbsent')),
      IntCellValue(report.absent),
    ]);
    sheet.appendRow([
      TextCellValue(AppTranslations.text(langCode, 'xlsLeave')),
      IntCellValue(report.leaves),
    ]);
    sheet.appendRow([
      TextCellValue(AppTranslations.text(langCode, 'xlsHolidays')),
      IntCellValue(report.holidays),
    ]);
    sheet.appendRow([
      TextCellValue(AppTranslations.text(langCode, 'xlsIncompleteRecords')),
      IntCellValue(report.incompleteRecords),
    ]);
    sheet.appendRow([
      TextCellValue(AppTranslations.text(langCode, 'xlsOverallAttendanceRate')),
      TextCellValue('${report.attendanceRate.toStringAsFixed(1)}%'),
    ]);
    sheet.appendRow([
      TextCellValue(AppTranslations.text(langCode, 'xlsTotalLateHours')),
      DoubleCellValue(report.totalLateMinutes / 60.0),
    ]);
    sheet.appendRow([
      TextCellValue(AppTranslations.text(langCode, 'xlsTotalWorkedHours')),
      DoubleCellValue(report.totalWorkedHours),
    ]);

    // Formatting adjustments can be added here
  }

  void _buildEmployeesOverview(
    Excel excel,
    AttendanceReport report,
    String langCode,
  ) {
    final sheet = excel[AppTranslations.text(langCode, 'xlsSheetEmployees')];

    sheet.appendRow([
      TextCellValue(AppTranslations.text(langCode, 'xlsColDepartment')),
      TextCellValue(AppTranslations.text(langCode, 'xlsColEmployeeId')),
      TextCellValue(AppTranslations.text(langCode, 'xlsColEmployeeName')),
      TextCellValue(AppTranslations.text(langCode, 'xlsColSchedule')),
      TextCellValue(AppTranslations.text(langCode, 'xlsColExpectedDays')),
      TextCellValue(AppTranslations.text(langCode, 'xlsColPresent')),
      TextCellValue(AppTranslations.text(langCode, 'xlsColLate')),
      TextCellValue(AppTranslations.text(langCode, 'xlsColAbsent')),
      TextCellValue(AppTranslations.text(langCode, 'xlsColLeave')),
      TextCellValue(AppTranslations.text(langCode, 'xlsColHolidays')),
      TextCellValue(AppTranslations.text(langCode, 'xlsColIncomplete')),
      TextCellValue(AppTranslations.text(langCode, 'xlsColLateHours')),
      TextCellValue(AppTranslations.text(langCode, 'xlsColWorkedHours')),
      TextCellValue(AppTranslations.text(langCode, 'xlsColAttendanceRate')),
    ]);

    for (var emp in report.employeeSummaries) {
      sheet.appendRow([
        TextCellValue(emp.department),
        TextCellValue(emp.employeeId),
        TextCellValue(emp.employeeName),
        TextCellValue(emp.schedule),
        IntCellValue(emp.expectedWorkingDays),
        IntCellValue(emp.present),
        IntCellValue(emp.late),
        IntCellValue(emp.absent),
        IntCellValue(emp.leaves),
        IntCellValue(emp.holidays),
        IntCellValue(emp.incomplete),
        DoubleCellValue(emp.totalLateMinutes / 60.0),
        DoubleCellValue(emp.totalWorkedHours),
        DoubleCellValue(emp.attendanceRate),
      ]);
    }
  }

  void _buildDetailedAttendance(
    Excel excel,
    AttendanceReport report,
    String langCode,
  ) {
    final sheet = excel[AppTranslations.text(langCode, 'xlsSheetDetailed')];

    sheet.appendRow([
      TextCellValue(AppTranslations.text(langCode, 'xlsColDate')),
      TextCellValue(AppTranslations.text(langCode, 'xlsColEmployeeId')),
      TextCellValue(AppTranslations.text(langCode, 'xlsColEmployee')),
      TextCellValue(AppTranslations.text(langCode, 'xlsColDepartment')),
      TextCellValue(AppTranslations.text(langCode, 'xlsColSchedule')),
      TextCellValue(AppTranslations.text(langCode, 'xlsColExpectedToWork')),
      TextCellValue(AppTranslations.text(langCode, 'xlsColCheckIn')),
      TextCellValue(AppTranslations.text(langCode, 'xlsColCheckOut')),
      TextCellValue(AppTranslations.text(langCode, 'xlsColStatus')),
      TextCellValue(AppTranslations.text(langCode, 'xlsColLateHrsShort')),
      TextCellValue(AppTranslations.text(langCode, 'xlsColWorkHours')),
      TextCellValue(AppTranslations.text(langCode, 'xlsColDevice')),
      TextCellValue(AppTranslations.text(langCode, 'xlsColNotes')),
    ]);

    final dateFormat = DateFormat('yyyy-MM-dd');
    final timeFormat = DateFormat('HH:mm:ss');

    for (var record in report.detailedRecords) {
      sheet.appendRow([
        TextCellValue(dateFormat.format(record.date)),
        TextCellValue(record.employeeId),
        TextCellValue(record.employeeName),
        TextCellValue(record.department),
        TextCellValue(record.schedule),
        TextCellValue(
          record.expectedToWork
              ? AppTranslations.text(langCode, 'yes')
              : AppTranslations.text(langCode, 'no'),
        ),
        TextCellValue(
          record.checkIn != null ? timeFormat.format(record.checkIn!) : '—',
        ),
        TextCellValue(
          record.checkOut != null ? timeFormat.format(record.checkOut!) : '—',
        ),
        TextCellValue(
          AppTranslations.text(langCode, record.status.toLowerCase()),
        ),
        DoubleCellValue(record.lateMinutes / 60.0),
        DoubleCellValue(record.workHours),
        TextCellValue(record.device),
        TextCellValue(record.notes),
      ]);
    }
  }
}
