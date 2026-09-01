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

    final headerStyle = CellStyle(
      backgroundColorHex: ExcelColor.fromHexString('#1B5E20'),
      fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
      bold: true,
    );

    final headers = [
      AppTranslations.text(langCode, 'xlsColDepartment'),
      AppTranslations.text(langCode, 'xlsColEmployeeId'),
      AppTranslations.text(langCode, 'xlsColEmployeeName'),
      AppTranslations.text(langCode, 'xlsColSchedule'),
      AppTranslations.text(langCode, 'xlsColExpectedDays'),
      AppTranslations.text(langCode, 'xlsColPresent'),
      AppTranslations.text(langCode, 'xlsColLate'),
      AppTranslations.text(langCode, 'xlsColAbsent'),
      AppTranslations.text(langCode, 'xlsColLeave'),
      AppTranslations.text(langCode, 'xlsColHolidays'),
      AppTranslations.text(langCode, 'xlsColIncomplete'),
      AppTranslations.text(langCode, 'xlsColLateHours'),
      AppTranslations.text(langCode, 'xlsColWorkedHours'),
      AppTranslations.text(langCode, 'xlsColAttendanceRate'),
    ];

    sheet.appendRow(headers.map((h) => TextCellValue(h)).toList());

    for (int col = 0; col < headers.length; col++) {
      final cell =
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0));
      cell.cellStyle = headerStyle;
    }

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

    final headerStyle = CellStyle(
      backgroundColorHex: ExcelColor.fromHexString('#1B5E20'),
      fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
      bold: true,
    );

    final presentStyle = CellStyle(
      backgroundColorHex: ExcelColor.fromHexString('#C8E6C9'),
      fontColorHex: ExcelColor.fromHexString('#1B5E20'),
    );

    final absentStyle = CellStyle(
      backgroundColorHex: ExcelColor.fromHexString('#FFCDD2'),
      fontColorHex: ExcelColor.fromHexString('#B71C1C'),
    );

    final lateStyle = CellStyle(
      backgroundColorHex: ExcelColor.fromHexString('#FFE0B2'),
      fontColorHex: ExcelColor.fromHexString('#E65100'),
    );

    final headers = [
      AppTranslations.text(langCode, 'xlsColDate'),
      AppTranslations.text(langCode, 'xlsColEmployeeId'),
      AppTranslations.text(langCode, 'xlsColEmployee'),
      AppTranslations.text(langCode, 'xlsColDepartment'),
      AppTranslations.text(langCode, 'xlsColSchedule'),
      AppTranslations.text(langCode, 'xlsColExpectedToWork'),
      AppTranslations.text(langCode, 'xlsColCheckIn'),
      AppTranslations.text(langCode, 'xlsColCheckOut'),
      AppTranslations.text(langCode, 'xlsColStatus'),
      AppTranslations.text(langCode, 'xlsColLateHrsShort'),
      AppTranslations.text(langCode, 'xlsColWorkHours'),
      AppTranslations.text(langCode, 'xlsColDevice'),
      AppTranslations.text(langCode, 'xlsColNotes'),
    ];

    sheet.appendRow(headers.map((h) => TextCellValue(h)).toList());

    for (int col = 0; col < headers.length; col++) {
      final cell =
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0));
      cell.cellStyle = headerStyle;
    }

    final dateFormat = DateFormat('yyyy-MM-dd');
    final timeFormat = DateFormat('HH:mm:ss');

    int rowIndex = 1;
    for (var record in report.detailedRecords) {
      final statusLower = record.status.toLowerCase();
      final isAbsent = statusLower == 'absent';

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
          !isAbsent && record.checkIn != null
              ? timeFormat.format(record.checkIn!)
              : '—',
        ),
        TextCellValue(
          !isAbsent && record.checkOut != null
              ? timeFormat.format(record.checkOut!)
              : '—',
        ),
        TextCellValue(
          AppTranslations.text(langCode, statusLower),
        ),
        DoubleCellValue(record.lateMinutes / 60.0),
        DoubleCellValue(record.workHours),
        TextCellValue(record.device),
        TextCellValue(record.notes),
      ]);

      // Apply cell styling to status cell (column index 8)
      final statusCell = sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: rowIndex));
      if (statusLower == 'present') {
        statusCell.cellStyle = presentStyle;
      } else if (statusLower == 'absent') {
        statusCell.cellStyle = absentStyle;
      } else if (statusLower == 'late') {
        statusCell.cellStyle = lateStyle;
      }

      rowIndex++;
    }
  }
}
