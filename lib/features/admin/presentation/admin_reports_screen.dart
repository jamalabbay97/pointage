import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart' as xl;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:universal_io/io.dart';

import '../../../core/services/app_translations.dart';

class AdminReportsScreen extends ConsumerStatefulWidget {
  const AdminReportsScreen({super.key});

  @override
  ConsumerState<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends ConsumerState<AdminReportsScreen> {
  final _db = FirebaseFirestore.instance;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _statusFilter = 'All';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(ref.tr('reportsAnalytics')),
      ),
      body: _isWide
          ? Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: _buildBody(),
              ),
            )
          : _buildBody(),
    );
  }

  static bool get _isWide =>
      kIsWeb ||
      defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.linux;

  Widget _buildBody() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              SearchBar(
                controller: _searchController,
                hintText: ref.tr('searchEmployee'),
                leading: const Icon(Icons.search),
                trailing: _searchController.text.isNotEmpty
                    ? [
                        IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        ),
                      ]
                    : null,
                onChanged: (val) => setState(() => _searchQuery = val.trim()),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: ['All', 'Present', 'Late'].map((statusKey) {
                          final label = statusKey == 'All'
                              ? ref.tr('all')
                              : statusKey == 'Present'
                                  ? ref.tr('present')
                                  : ref.tr('late');
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(label),
                              selected: _statusFilter == statusKey,
                              onSelected: (selected) {
                                if (selected) setState(() => _statusFilter = statusKey);
                              },
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  StreamBuilder<QuerySnapshot>(
                    stream: _db.collection('attendance').snapshots(),
                    builder: (context, snapshot) {
                      final docs = snapshot.data?.docs ?? [];
                      final records = docs.map((d) => d.data() as Map<String, dynamic>).toList();
                      return PopupMenuButton<String>(
                        icon: const Icon(Icons.download_rounded),
                        tooltip: ref.tr('export'),
                        onSelected: (val) {
                          if (val == 'pdf') {
                            _exportPdf(records);
                          } else if (val == 'excel') {
                            _exportExcel(records);
                          }
                        },
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: 'pdf',
                            child: Row(
                              children: [
                                const Icon(Icons.picture_as_pdf, color: Colors.red),
                                const SizedBox(width: 8),
                                Text(ref.tr('exportPdf')),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'excel',
                            child: Row(
                              children: [
                                const Icon(Icons.table_chart, color: Colors.green),
                                const SizedBox(width: 8),
                                Text(ref.tr('exportExcel')),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _db.collection('attendance').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text('Error loading reports: ${snapshot.error}'));
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final docs = snapshot.data?.docs ?? [];
              var allRecords = docs.map((d) => d.data() as Map<String, dynamic>).toList();

              // 1. Multi-field Filter by search query
              if (_searchQuery.isNotEmpty) {
                allRecords = allRecords.where((r) {
                  final name = (r['employeeName'] as String? ?? '').toLowerCase();
                  final empId = (r['employeeId'] as String? ?? '').toLowerCase();
                  final date = (r['date'] as String? ?? '').toLowerCase();
                  final device = (r['deviceModel'] as String? ?? '').toLowerCase();
                  final status = (r['status'] as String? ?? '').toLowerCase();
                  final q = _searchQuery.toLowerCase();
                  return name.contains(q) ||
                      empId.contains(q) ||
                      date.contains(q) ||
                      device.contains(q) ||
                      status.contains(q);
                }).toList();
              }

              // 2. Compute Summary Metrics BEFORE status tab filtering
              final totalRecordsCount = allRecords.length;
              final presentCount = allRecords.where((r) {
                final st = (r['status'] as String? ?? '').toLowerCase();
                return st == 'present';
              }).length;

              // 3. Filter by Status Chip for list display
              var displayedRecords = List<Map<String, dynamic>>.from(allRecords);
              if (_statusFilter != 'All') {
                displayedRecords = displayedRecords.where((r) {
                  final status = (r['status'] as String? ?? '').toLowerCase();
                  return status == _statusFilter.toLowerCase();
                }).toList();
              }

              // Sort descending by time
              displayedRecords.sort((a, b) {
                final t1 = a['time'] as String? ?? '';
                final t2 = b['time'] as String? ?? '';
                return t2.compareTo(t1);
              });

              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: Card(
                            color: Colors.blue.withValues(alpha: 0.1),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                children: [
                                  Text(
                                    '$totalRecordsCount',
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue,
                                    ),
                                  ),
                                  Text(ref.tr('totalRecords'), style: const TextStyle(fontSize: 12)),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Card(
                            color: Colors.green.withValues(alpha: 0.1),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                children: [
                                  Text(
                                    '$presentCount',
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green,
                                    ),
                                  ),
                                  Text(ref.tr('verifiedPresent'), style: const TextStyle(fontSize: 12)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: displayedRecords.isEmpty
                        ? Center(
                            child: Text(
                              ref.tr('noRecordsFound'),
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: displayedRecords.length,
                            itemBuilder: (context, index) {
                              final record = displayedRecords[index];
                              final name = record['employeeName'] ?? 'Unknown';
                              final date = record['date'] ?? '';
                              final timeStr = record['time'] ?? '';
                              final status = (record['status'] as String? ?? 'present').toLowerCase();
                              final device = record['deviceModel'] ?? 'Device';
                              final battery = record['batteryLevel'] ?? 0;

                              String formattedTime = timeStr;
                              try {
                                final dt = DateTime.parse(timeStr);
                                formattedTime = DateFormat('HH:mm:ss').format(dt);
                              } catch (_) {}

                              final isLate = status == 'late';
                              final statusLabel = isLate ? ref.tr('late') : ref.tr('present');

                              return Card(
                                margin: const EdgeInsets.only(bottom: 10),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: isLate
                                        ? Colors.orange.withValues(alpha: 0.2)
                                        : Colors.green.withValues(alpha: 0.2),
                                    child: Icon(
                                      isLate ? Icons.access_time_filled : Icons.check_circle_outline,
                                      color: isLate ? Colors.orange : Colors.green,
                                    ),
                                  ),
                                  title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                  subtitle: Text(
                                    '${ref.tr('date')}: $date at $formattedTime\n${ref.tr('device')}: $device • ${ref.tr('battery')}: $battery%',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  isThreeLine: true,
                                  trailing: Chip(
                                    label: Text(
                                      statusLabel.toUpperCase(),
                                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                                    ),
                                    backgroundColor: isLate
                                        ? Colors.orange.withValues(alpha: 0.15)
                                        : Colors.green.withValues(alpha: 0.15),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _exportPdf(List<Map<String, dynamic>> records) async {
    try {
      final pdf = pw.Document();
      pdf.addPage(
        pw.Page(
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Header(
                  level: 0,
                  child: pw.Text(
                    'Chez Le Pointage - Official Attendance Report',
                    style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
                  ),
                ),
                pw.SizedBox(height: 10),
                pw.Text('Generated on: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())}'),
                pw.Text('Total Logged Records: ${records.length}'),
                pw.SizedBox(height: 20),
                pw.TableHelper.fromTextArray(
                  headers: ['Employee', 'Date', 'Time', 'Status', 'Device'],
                  data: records.map((r) {
                    final timeStr = r['time'] ?? '';
                    String ft = timeStr;
                    try {
                      ft = DateFormat('HH:mm:ss').format(DateTime.parse(timeStr));
                    } catch (_) {}
                    return [
                      r['employeeName'] ?? 'N/A',
                      r['date'] ?? 'N/A',
                      ft,
                      (r['status'] as String? ?? 'present').toUpperCase(),
                      r['deviceModel'] ?? 'N/A',
                    ];
                  }).toList(),
                ),
              ],
            );
          },
        ),
      );

      final outputDir = Directory.systemTemp.path;
      final file = File('$outputDir/Attendance_Report_${DateTime.now().millisecondsSinceEpoch}.pdf');
      await file.writeAsBytes(await pdf.save());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${ref.tr('pdfGenerated')}: ${file.path}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${ref.tr('errorGenerating')}: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _exportExcel(List<Map<String, dynamic>> records) async {
    try {
      final excel = xl.Excel.createExcel();
      final sheet = excel['Attendance Report'];

      sheet.appendRow([
        xl.TextCellValue('Employee Name'),
        xl.TextCellValue('Date'),
        xl.TextCellValue('Time'),
        xl.TextCellValue('Status'),
        xl.TextCellValue('Device Model'),
        xl.TextCellValue('Latitude'),
        xl.TextCellValue('Longitude'),
        xl.TextCellValue('Battery Level'),
      ]);

      for (final r in records) {
        sheet.appendRow([
          xl.TextCellValue(r['employeeName']?.toString() ?? ''),
          xl.TextCellValue(r['date']?.toString() ?? ''),
          xl.TextCellValue(r['time']?.toString() ?? ''),
          xl.TextCellValue(r['status']?.toString() ?? ''),
          xl.TextCellValue(r['deviceModel']?.toString() ?? ''),
          xl.TextCellValue(r['latitude']?.toString() ?? ''),
          xl.TextCellValue(r['longitude']?.toString() ?? ''),
          xl.TextCellValue(r['batteryLevel']?.toString() ?? ''),
        ]);
      }

      final outputDir = Directory.systemTemp.path;
      final file = File('$outputDir/Attendance_Sheet_${DateTime.now().millisecondsSinceEpoch}.xlsx');
      final bytes = excel.encode();
      if (bytes != null) {
        await file.writeAsBytes(bytes);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${ref.tr('excelGenerated')}: ${file.path}'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${ref.tr('errorGenerating')}: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}
