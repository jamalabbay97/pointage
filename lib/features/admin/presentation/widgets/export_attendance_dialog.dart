import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart' as xl;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:universal_io/io.dart';

import '../../../../core/models/user_model.dart';
import '../../../../core/services/app_translations.dart';

enum ExportTarget { all, single }

enum ExportDateRange { day, month, year }

enum ExportFormat { pdf, excel }

class ExportAttendanceDialog extends ConsumerStatefulWidget {
  const ExportAttendanceDialog({
    super.key,
    required this.availableEmployees,
  });

  final List<UserModel> availableEmployees;

  static Future<void> show(
    BuildContext context,
    List<UserModel> availableEmployees,
  ) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => ExportAttendanceDialog(
        availableEmployees: availableEmployees,
      ),
    );
  }

  @override
  ConsumerState<ExportAttendanceDialog> createState() =>
      _ExportAttendanceDialogState();
}

class _ExportAttendanceDialogState
    extends ConsumerState<ExportAttendanceDialog> {
  ExportTarget _target = ExportTarget.all;
  String? _selectedEmployeeId;
  ExportDateRange _dateRange = ExportDateRange.month;
  DateTime _selectedDate = DateTime.now();
  ExportFormat _format = ExportFormat.pdf;

  String? _customSavePath;
  bool _isGenerating = false;

  @override
  void initState() {
    super.initState();
    if (widget.availableEmployees.isNotEmpty) {
      _selectedEmployeeId = widget.availableEmployees.first.uid;
    }
  }

  String get _rangeLabel {
    switch (_dateRange) {
      case ExportDateRange.day:
        return DateFormat.yMMMMd().format(_selectedDate);
      case ExportDateRange.month:
        return DateFormat.yMMMM().format(_selectedDate);
      case ExportDateRange.year:
        return DateFormat.y().format(_selectedDate);
    }
  }

  Future<void> _pickDestinationPath() async {
    try {
      final ext = _format == ExportFormat.pdf ? 'pdf' : 'xlsx';
      final defaultName =
          'Attendance_Report_${DateFormat('yyyyMMdd').format(_selectedDate)}.$ext';

      final resultPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Select Export Save Destination',
        fileName: defaultName,
        type: FileType.custom,
        allowedExtensions: [ext],
      );

      if (resultPath != null && mounted) {
        setState(() => _customSavePath = resultPath);
      }
    } catch (e) {
      debugPrint('File picker error: $e');
    }
  }

  Future<void> _handleDownload() async {
    setState(() => _isGenerating = true);
    try {
      final records = await _fetchAttendanceRecords();

      if (records.isEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ref.tr('noRecordsFound')),
            backgroundColor: Colors.orange,
          ),
        );
        setState(() => _isGenerating = false);
        return;
      }

      Uint8List fileBytes;
      String fileExtension;

      if (_format == ExportFormat.pdf) {
        fileBytes = await _buildPdfBytes(records);
        fileExtension = 'pdf';
      } else {
        fileBytes = _buildExcelBytes(records);
        fileExtension = 'xlsx';
      }

      final fileName =
          'Attendance_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.$fileExtension';
      String savedLocationDesc = fileName;

      if (kIsWeb) {
        // Web direct browser download
        await FilePicker.platform.saveFile(
          dialogTitle: 'Download Attendance Report',
          fileName: fileName,
          bytes: fileBytes,
        );
        savedLocationDesc = 'Downloads Folder';
      } else {
        // Desktop / Mobile
        String targetPath = _customSavePath ?? '';
        if (targetPath.isEmpty) {
          final chosenPath = await FilePicker.platform.saveFile(
            dialogTitle: 'Save Attendance Report As',
            fileName: fileName,
            type: FileType.custom,
            allowedExtensions: [fileExtension],
          );
          if (chosenPath == null) {
            // User cancelled save dialog
            setState(() => _isGenerating = false);
            return;
          }
          targetPath = chosenPath;
        }

        final file = File(targetPath);
        await file.writeAsBytes(fileBytes);
        savedLocationDesc = file.path;
      }

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${ref.tr('reportDownloaded')} $savedLocationDesc'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isGenerating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${ref.tr('errorGenerating')}: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<List<Map<String, dynamic>>> _fetchAttendanceRecords() async {
    final db = FirebaseFirestore.instance;
    final querySnap = await db.collection('attendance').get();
    final rawDocs = querySnap.docs.map((d) => d.data()).toList();

    // Determine employee target filter UIDs
    final targetUserIds = <String>{};
    if (_target == ExportTarget.all) {
      targetUserIds.addAll(widget.availableEmployees.map((u) => u.uid));
    } else if (_selectedEmployeeId != null) {
      targetUserIds.add(_selectedEmployeeId!);
    }

    final employeeNameMap = {
      for (final u in widget.availableEmployees) u.uid: u.displayName,
    };

    // Calculate Date Range start and end
    DateTime startDate;
    DateTime endDate;

    switch (_dateRange) {
      case ExportDateRange.day:
        startDate = DateTime(
          _selectedDate.year,
          _selectedDate.month,
          _selectedDate.day,
        );
        endDate = DateTime(
          _selectedDate.year,
          _selectedDate.month,
          _selectedDate.day,
          23,
          59,
          59,
        );
        break;
      case ExportDateRange.month:
        startDate = DateTime(_selectedDate.year, _selectedDate.month, 1);
        endDate = DateTime(
          _selectedDate.year,
          _selectedDate.month + 1,
          0,
          23,
          59,
          59,
        );
        break;
      case ExportDateRange.year:
        startDate = DateTime(_selectedDate.year, 1, 1);
        endDate = DateTime(_selectedDate.year, 12, 31, 23, 59, 59);
        break;
    }

    final filtered = <Map<String, dynamic>>[];
    for (final doc in rawDocs) {
      final empId = doc['employeeId'] as String? ?? '';
      if (targetUserIds.isNotEmpty && !targetUserIds.contains(empId)) {
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

      if (parsedDate.isAfter(startDate.subtract(const Duration(seconds: 1))) &&
          parsedDate.isBefore(endDate.add(const Duration(seconds: 1)))) {
        final recordMap = Map<String, dynamic>.from(doc);
        recordMap['employeeName'] =
            doc['employeeName'] ?? employeeNameMap[empId] ?? 'Employee';
        filtered.add(recordMap);
      }
    }

    filtered.sort((a, b) {
      final da = a['date']?.toString() ?? '';
      final db = b['date']?.toString() ?? '';
      return db.compareTo(da);
    });

    return filtered;
  }

  Future<Uint8List> _buildPdfBytes(List<Map<String, dynamic>> records) async {
    final pdf = pw.Document();

    String targetDesc = ref.tr('allEmployees');
    if (_target == ExportTarget.single && _selectedEmployeeId != null) {
      final emp = widget.availableEmployees.firstWhere(
        (u) => u.uid == _selectedEmployeeId,
        orElse: () => const UserModel(
          uid: '',
          email: '',
          displayName: 'Employee',
          role: 'employee',
        ),
      );
      targetDesc = emp.displayName;
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (pw.Context context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Chez Le Pointage - Attendance Report',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text(
                  DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now()),
                  style: const pw.TextStyle(
                    fontSize: 10,
                    color: PdfColors.grey700,
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 4),
            pw.Divider(thickness: 1, color: PdfColors.blueGrey300),
            pw.SizedBox(height: 8),
          ],
        ),
        footer: (pw.Context context) => pw.Container(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
          ),
        ),
        build: (pw.Context context) => [
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: const pw.BoxDecoration(
              color: PdfColors.blue50,
              borderRadius: pw.BorderRadius.all(pw.Radius.circular(8)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Report Summary',
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blue900,
                  ),
                ),
                pw.SizedBox(height: 6),
                pw.Row(
                  children: [
                    pw.Text(
                      'Target: ',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    ),
                    pw.Text(targetDesc),
                    pw.SizedBox(width: 20),
                    pw.Text(
                      'Period: ',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    ),
                    pw.Text(_rangeLabel),
                    pw.SizedBox(width: 20),
                    pw.Text(
                      'Total Records: ',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    ),
                    pw.Text('${records.length}'),
                  ],
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 16),
          pw.TableHelper.fromTextArray(
            headers: [
              'Employee Name',
              'Date',
              'Check-in',
              'Check-out',
              'Status',
              'Device',
            ],
            headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.blue700),
            cellHeight: 24,
            cellAlignments: {
              0: pw.Alignment.centerLeft,
              1: pw.Alignment.center,
              2: pw.Alignment.center,
              3: pw.Alignment.center,
              4: pw.Alignment.center,
              5: pw.Alignment.centerLeft,
            },
            data: records.map((r) {
              final rawDate = r['date']?.toString() ?? '';
              final parsedDate = DateTime.tryParse(rawDate);
              final formattedDate = parsedDate != null
                  ? DateFormat('yyyy-MM-dd').format(parsedDate)
                  : rawDate;

              String formatTime(Object? val) {
                final str = val?.toString() ?? '';
                final p = DateTime.tryParse(str);
                return p != null
                    ? DateFormat('HH:mm:ss').format(p)
                    : (str.isEmpty ? '-' : str);
              }

              return [
                r['employeeName']?.toString() ?? 'N/A',
                formattedDate,
                formatTime(r['time']),
                formatTime(r['checkoutTime']),
                (r['status']?.toString() ?? 'present').toUpperCase(),
                r['deviceModel']?.toString() ?? 'Mobile Device',
              ];
            }).toList(),
          ),
        ],
      ),
    );

    return pdf.save();
  }

  Uint8List _buildExcelBytes(List<Map<String, dynamic>> records) {
    final excel = xl.Excel.createExcel();
    final sheet = excel['Attendance Report'];

    sheet.appendRow([
      xl.TextCellValue('Employee Name'),
      xl.TextCellValue('Date'),
      xl.TextCellValue('Check-in Time'),
      xl.TextCellValue('Check-out Time'),
      xl.TextCellValue('Status'),
      xl.TextCellValue('Device Model'),
      xl.TextCellValue('Operating System'),
    ]);

    for (final r in records) {
      final rawDate = r['date']?.toString() ?? '';
      final parsedDate = DateTime.tryParse(rawDate);
      final formattedDate = parsedDate != null
          ? DateFormat('yyyy-MM-dd').format(parsedDate)
          : rawDate;

      String formatTime(Object? val) {
        final str = val?.toString() ?? '';
        final p = DateTime.tryParse(str);
        return p != null
            ? DateFormat('HH:mm:ss').format(p)
            : (str.isEmpty ? '-' : str);
      }

      sheet.appendRow([
        xl.TextCellValue(r['employeeName']?.toString() ?? ''),
        xl.TextCellValue(formattedDate),
        xl.TextCellValue(formatTime(r['time'])),
        xl.TextCellValue(formatTime(r['checkoutTime'])),
        xl.TextCellValue((r['status']?.toString() ?? 'present').toUpperCase()),
        xl.TextCellValue(r['deviceModel']?.toString() ?? 'Mobile Device'),
        xl.TextCellValue(r['operatingSystem']?.toString() ?? 'Mobile'),
      ]);
    }

    final encoded = excel.encode();
    return Uint8List.fromList(encoded ?? []);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        width: 560,
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.file_download_rounded,
                      color: Theme.of(context).colorScheme.primary,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ref.tr('exportAttendanceData'),
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Configure export options and select destination',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // 1. Export Target Section
              Text(
                ref.tr('exportTarget'),
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _TargetTile(
                      label: ref.tr('allEmployees'),
                      isSelected: _target == ExportTarget.all,
                      onTap: () => setState(() => _target = ExportTarget.all),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _TargetTile(
                      label: ref.tr('singleEmployee'),
                      isSelected: _target == ExportTarget.single,
                      onTap: () =>
                          setState(() => _target = ExportTarget.single),
                    ),
                  ),
                ],
              ),
              if (_target == ExportTarget.single) ...[
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _selectedEmployeeId,
                  decoration: InputDecoration(
                    labelText: ref.tr('selectEmployee'),
                    prefixIcon: const Icon(Icons.person_outline),
                    border: const OutlineInputBorder(),
                  ),
                  items: widget.availableEmployees
                      .map(
                        (emp) => DropdownMenuItem(
                          value: emp.uid,
                          child: Text('${emp.displayName} (${emp.email})'),
                        ),
                      )
                      .toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedEmployeeId = val);
                  },
                ),
              ],
              const SizedBox(height: 16),

              // 2. Date Range Section
              Text(
                ref.tr('dateRange'),
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      label: Center(child: Text(ref.tr('oneDay'))),
                      selected: _dateRange == ExportDateRange.day,
                      onSelected: (sel) {
                        if (sel) {
                          setState(() => _dateRange = ExportDateRange.day);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ChoiceChip(
                      label: Center(child: Text(ref.tr('oneMonth'))),
                      selected: _dateRange == ExportDateRange.month,
                      onSelected: (sel) {
                        if (sel) {
                          setState(() => _dateRange = ExportDateRange.month);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ChoiceChip(
                      label: Center(child: Text(ref.tr('oneYear'))),
                      selected: _dateRange == ExportDateRange.year,
                      onSelected: (sel) {
                        if (sel) {
                          setState(() => _dateRange = ExportDateRange.year);
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.calendar_month_outlined, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Selected Period: $_rangeLabel',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) {
                        setState(() => _selectedDate = picked);
                      }
                    },
                    icon: const Icon(Icons.edit_calendar, size: 18),
                    label: const Text('Change Date'),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 3. Export Format Section
              Text(
                ref.tr('exportFormat'),
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _format = ExportFormat.pdf),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _format == ExportFormat.pdf
                              ? Colors.red.withValues(alpha: 0.1)
                              : (isDark
                                  ? const Color(0xFF262626)
                                  : Colors.grey.shade100),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _format == ExportFormat.pdf
                                ? Colors.red
                                : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.picture_as_pdf, color: Colors.red),
                            SizedBox(width: 8),
                            Text(
                              'PDF Document',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _format = ExportFormat.excel),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _format == ExportFormat.excel
                              ? Colors.green.withValues(alpha: 0.1)
                              : (isDark
                                  ? const Color(0xFF262626)
                                  : Colors.grey.shade100),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _format == ExportFormat.excel
                                ? Colors.green
                                : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.table_chart_rounded,
                              color: Colors.green,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Excel (.xlsx)',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 4. Save Destination Selection
              if (!kIsWeb) ...[
                Text(
                  ref.tr('destinationPath'),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade400),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _customSavePath ?? 'Default file save location',
                          style: TextStyle(
                            fontSize: 13,
                            color: _customSavePath == null ? Colors.grey : null,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: _pickDestinationPath,
                      icon: const Icon(Icons.folder_open),
                      label: Text(ref.tr('chooseLocation')),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ] else ...[
                const SizedBox(height: 12),
              ],

              // Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed:
                        _isGenerating ? null : () => Navigator.pop(context),
                    child: Text(ref.tr('cancel')),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: _isGenerating ? null : _handleDownload,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                    ),
                    icon: _isGenerating
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.download_rounded),
                    label: Text(
                      _isGenerating
                          ? ref.tr('generatingReport')
                          : ref.tr('downloadReport'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A simple selectable tile replacing deprecated RadioListTile
class _TargetTile extends StatelessWidget {
  const _TargetTile({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? colorScheme.primary : colorScheme.outline,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
          color:
              isSelected ? colorScheme.primary.withValues(alpha: 0.08) : null,
        ),
        child: Row(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? colorScheme.primary : colorScheme.outline,
                  width: 2,
                ),
                color: isSelected ? colorScheme.primary : null,
              ),
              child: isSelected
                  ? const Icon(Icons.check, size: 12, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 8),
            Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
          ],
        ),
      ),
    );
  }
}
