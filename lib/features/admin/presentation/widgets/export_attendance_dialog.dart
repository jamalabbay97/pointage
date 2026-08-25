import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/models/user_model.dart';
import '../../../../core/services/app_translations.dart';
import '../../domain/services/report_data_service.dart';
import '../../domain/services/excel_export_service.dart';
import '../../domain/services/pdf_export_service.dart';
import '../../domain/models/attendance_report_model.dart';
import 'web_download_stub.dart';

enum ExportTarget { all, single }

enum ExportDateRange { day, month, year, custom }

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

  DateTime _startDate = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _endDate = DateTime.now();

  bool _isGenerating = false;
  AttendanceReport? _previewReport;

  final ReportDataService _dataService = ReportDataService();
  final ExcelExportService _excelService = ExcelExportService();
  final PdfExportService _pdfService = PdfExportService();

  @override
  void initState() {
    super.initState();
    if (widget.availableEmployees.isNotEmpty) {
      _selectedEmployeeId = widget.availableEmployees.first.uid;
    }
  }

  void _updateDateRange() {
    final now = DateTime.now();
    switch (_dateRange) {
      case ExportDateRange.day:
        _startDate = DateTime(now.year, now.month, now.day);
        _endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
        break;
      case ExportDateRange.month:
        _startDate = DateTime(now.year, now.month, 1);
        _endDate = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
        break;
      case ExportDateRange.year:
        _startDate = DateTime(now.year, 1, 1);
        _endDate = DateTime(now.year, 12, 31, 23, 59, 59);
        break;
      case ExportDateRange.custom:
        // Keep existing custom dates
        break;
    }
  }

  Future<void> _generatePreview() async {
    setState(() {
      _isGenerating = true;
      _previewReport = null;
    });

    try {
      final report = await _dataService.generateReport(
        startDate: _startDate,
        endDate: _endDate,
        targetEmployeeId:
            _target == ExportTarget.single ? _selectedEmployeeId : null,
      );

      if (mounted) {
        setState(() {
          _previewReport = report;
          _isGenerating = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isGenerating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating preview: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handleDownload(ExportFormat format) async {
    if (_previewReport == null) {
      await _generatePreview();
      if (!mounted) return;
      if (_previewReport == null) return;
    }

    if (_previewReport!.detailedRecords.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ref.tr('noRecordsFound')),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isGenerating = true);

    try {
      Uint8List fileBytes;
      String fileExtension;

      if (format == ExportFormat.pdf) {
        fileBytes = await _pdfService.generatePdf(_previewReport!);
        fileExtension = 'pdf';
      } else {
        fileBytes = _excelService.generateExcel(_previewReport!);
        fileExtension = 'xlsx';
      }

      final fileName =
          'Attendance_Report_${DateFormat('yyyyMMdd').format(DateTime.now())}.$fileExtension';
      String savedLocationDesc = fileName;

      if (kIsWeb) {
        downloadFileWeb(fileBytes, fileName);
      } else if (Platform.isAndroid || Platform.isIOS) {
        Directory? outputDir;
        if (Platform.isAndroid) {
          outputDir = await getExternalStorageDirectory();
        }
        outputDir ??= await getApplicationDocumentsDirectory();

        final filePath = '${outputDir.path}/$fileName';
        final file = File(filePath);
        await file.writeAsBytes(fileBytes);
        savedLocationDesc = file.path;

        // ignore: deprecated_member_use
        await Share.shareXFiles(
          [XFile(file.path)],
          text: 'Attendance Report: $fileName',
        );
      } else {
        final chosenPath = await FilePicker.platform.saveFile(
          dialogTitle: 'Save Attendance Report As',
          fileName: fileName,
          type: FileType.custom,
          allowedExtensions: [fileExtension],
        );
        if (chosenPath != null) {
          final file = File(chosenPath);
          await file.writeAsBytes(fileBytes);
          savedLocationDesc = file.path;
        } else {
          setState(() => _isGenerating = false);
          return;
        }
      }

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${ref.tr('reportDownloaded')} $savedLocationDesc'),
            backgroundColor: Colors.green,
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

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Generate Attendance Report',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),

                // --- Configuration ---
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<ExportTarget>(
                    segments: [
                      ButtonSegment(
                        value: ExportTarget.all,
                        label: Text(ref.tr('allEmployees')),
                      ),
                      ButtonSegment(
                        value: ExportTarget.single,
                        label: Text(ref.tr('singleEmployee')),
                      ),
                    ],
                    selected: <ExportTarget>{_target},
                    onSelectionChanged: (Set<ExportTarget> newSelection) {
                      setState(() {
                        _target = newSelection.first;
                        _previewReport = null;
                      });
                    },
                  ),
                ),

                if (_target == ExportTarget.single)
                  DropdownButtonFormField<String>(
                    initialValue: _selectedEmployeeId,
                    decoration: const InputDecoration(
                      labelText: 'Select Employee',
                      border: OutlineInputBorder(),
                    ),
                    items: widget.availableEmployees
                        .map(
                          (e) => DropdownMenuItem(
                            value: e.uid,
                            child: Text(e.displayName),
                          ),
                        )
                        .toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _selectedEmployeeId = val;
                          _previewReport = null;
                        });
                      }
                    },
                  ),
                const SizedBox(height: 16),

                DropdownButtonFormField<ExportDateRange>(
                  initialValue: _dateRange,
                  decoration: const InputDecoration(
                    labelText: 'Date Range',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: ExportDateRange.day,
                      child: Text('Today'),
                    ),
                    DropdownMenuItem(
                      value: ExportDateRange.month,
                      child: Text('This Month'),
                    ),
                    DropdownMenuItem(
                      value: ExportDateRange.year,
                      child: Text('This Year'),
                    ),
                    DropdownMenuItem(
                      value: ExportDateRange.custom,
                      child: Text('Custom Range'),
                    ),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _dateRange = val;
                        _updateDateRange();
                        _previewReport = null;
                      });
                    }
                  },
                ),

                if (_dateRange == ExportDateRange.custom) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _startDate,
                              firstDate: DateTime(2020),
                              lastDate: _endDate,
                            );
                            if (picked != null) {
                              setState(() {
                                _startDate = picked;
                                _previewReport = null;
                              });
                            }
                          },
                          icon: const Icon(Icons.calendar_today, size: 16),
                          label:
                              Text(DateFormat('yyyy-MM-dd').format(_startDate)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _endDate,
                              firstDate: _startDate,
                              lastDate: DateTime.now(),
                            );
                            if (picked != null) {
                              setState(() {
                                _endDate = picked;
                                _previewReport = null;
                              });
                            }
                          },
                          icon: const Icon(Icons.calendar_today, size: 16),
                          label:
                              Text(DateFormat('yyyy-MM-dd').format(_endDate)),
                        ),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 24),

                // --- Preview Section ---
                if (_previewReport != null) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Preview Data',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Total Employees: ${_previewReport!.totalEmployees}',
                        ),
                        Text(
                          'Attendance Records: ${_previewReport!.present + _previewReport!.late}',
                        ),
                        Text(
                          'Attendance Rate: ${_previewReport!.attendanceRate.toStringAsFixed(1)}%',
                        ),
                        Text(
                          'Total Late Minutes: ${_previewReport!.totalLateMinutes}',
                        ),
                        Text(
                          'Total Worked Hours: ${_previewReport!.totalWorkedHours.toStringAsFixed(1)}',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                if (_isGenerating)
                  const Center(child: CircularProgressIndicator())
                else
                  Column(
                    children: [
                      if (_previewReport == null)
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: _generatePreview,
                            child: const Text('Generate Preview'),
                          ),
                        )
                      else ...[
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () =>
                                    _handleDownload(ExportFormat.excel),
                                icon: const Icon(
                                  Icons.table_chart,
                                  color: Colors.green,
                                ),
                                label: const Text('Export Excel'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () =>
                                    _handleDownload(ExportFormat.pdf),
                                icon: const Icon(
                                  Icons.picture_as_pdf,
                                  color: Colors.red,
                                ),
                                label: const Text('Export PDF'),
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
