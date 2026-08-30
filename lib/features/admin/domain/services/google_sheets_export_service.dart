import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';

import '../../../../core/models/user_model.dart';

class ManagerEmployeeGroup {
  const ManagerEmployeeGroup({
    required this.manager,
    required this.employees,
  });

  final UserModel manager;
  final List<UserModel> employees;
}

class GoogleSheetsExportService {
  Uint8List generateGoogleSheetWorkbook({
    required List<ManagerEmployeeGroup> managerGroups,
    required Map<String, String>
        attendanceRecords, // key: '$employeeId-$yyyyMMdd', value: status
    required DateTime month,
  }) {
    final excel = Excel.createExcel();

    // Track sheets created so we can delete the default 'Sheet1'
    final createdSheetNames = <String>[];

    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final dateFormat = DateFormat('yyyy-MM-dd');

    for (final group in managerGroups) {
      // Clean sheet name (Google Sheets / Excel tab name limit 31 chars, no invalid chars)
      var sheetName = group.manager.displayName.trim();
      if (sheetName.isEmpty) {
        sheetName = 'Manager_${group.manager.uid.substring(0, 5)}';
      }
      sheetName = sheetName.replaceAll(RegExp(r'[\\/*?:\[\]]'), '_');
      if (sheetName.length > 31) {
        sheetName = sheetName.substring(0, 31);
      }

      // Ensure unique sheet name
      var uniqueSheetName = sheetName;
      int counter = 1;
      while (createdSheetNames.contains(uniqueSheetName)) {
        final suffix = '_$counter';
        final maxLen = 31 - suffix.length;
        uniqueSheetName =
            '${sheetName.substring(0, sheetName.length > maxLen ? maxLen : sheetName.length)}$suffix';
        counter++;
      }

      createdSheetNames.add(uniqueSheetName);
      final sheet = excel[uniqueSheetName];

      // Row 1: Header Row
      final headers = <CellValue>[
        TextCellValue('Employee ID'),
        TextCellValue('Employee Name'),
        TextCellValue('Department'),
      ];

      for (int day = 1; day <= daysInMonth; day++) {
        final date = DateTime(month.year, month.month, day);
        headers.add(TextCellValue(DateFormat('E dd/MM').format(date)));
      }
      sheet.appendRow(headers);

      // Rows for each employee
      for (final emp in group.employees) {
        final row = <CellValue>[
          TextCellValue(emp.uid),
          TextCellValue(emp.displayName),
          TextCellValue(emp.department),
        ];

        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);

        for (int day = 1; day <= daysInMonth; day++) {
          final date = DateTime(month.year, month.month, day);
          final cellDate = DateTime(date.year, date.month, date.day);
          final dateKey = '${emp.uid}-${dateFormat.format(date)}';
          final status = attendanceRecords[dateKey]?.toLowerCase();
          final isFuture = cellDate.isAfter(today);

          String cellText = '—';
          if (status == 'present') {
            cellText = 'Present';
          } else if (status == 'absent') {
            cellText = 'Absent';
          } else if (status == 'late') {
            cellText = 'Late';
          } else if (!isFuture) {
            cellText = 'Absent';
          }

          row.add(TextCellValue(cellText));
        }

        sheet.appendRow(row);
      }
    }

    // Delete default 'Sheet1' if other sheets were created
    if (createdSheetNames.isNotEmpty && excel.sheets.containsKey('Sheet1')) {
      excel.delete('Sheet1');
    }

    return Uint8List.fromList(excel.encode() ?? []);
  }
}
