import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart' as xl;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:universal_io/io.dart';

class AdminReportsScreen extends StatefulWidget {
  const AdminReportsScreen({super.key});

  @override
  State<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends State<AdminReportsScreen> {
  final _db = FirebaseFirestore.instance;
  String _searchQuery = '';
  String _statusFilter = 'All';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance Reports & Analytics'),
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
    return StreamBuilder<QuerySnapshot>(
        stream: _db.collection('attendance').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error loading reports: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ?? [];
          var records = docs.map((d) => d.data() as Map<String, dynamic>).toList();

          if (_searchQuery.isNotEmpty) {
            records = records.where((r) {
              final name = (r['employeeName'] as String? ?? '').toLowerCase();
              return name.contains(_searchQuery.toLowerCase());
            }).toList();
          }

          if (_statusFilter != 'All') {
            records = records.where((r) {
              final status = (r['status'] as String? ?? '').toLowerCase();
              return status == _statusFilter.toLowerCase();
            }).toList();
          }

          final totalRecords = records.length;
          final presentCount = records.where((r) => r['status'] == 'present').length;

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Card(
                            color: Colors.blue.withValues(alpha: 0.1),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                children: [
                                  Text(
                                    '$totalRecords',
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue,
                                    ),
                                  ),
                                  const Text('Total Records', style: TextStyle(fontSize: 12)),
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
                                  const Text('Verified Present', style: TextStyle(fontSize: 12)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SearchBar(
                      hintText: 'Filter by employee name...',
                      leading: const Icon(Icons.search),
                      onChanged: (val) => setState(() => _searchQuery = val.trim()),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: ['All', 'Present', 'Late'].map((status) {
                                return Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: ChoiceChip(
                                    label: Text(status),
                                    selected: _statusFilter == status,
                                    onSelected: (selected) {
                                      if (selected) setState(() => _statusFilter = status);
                                    },
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.download_rounded),
                          tooltip: 'Export Report',
                          onSelected: (val) {
                            if (val == 'pdf') {
                              _exportPdf(records);
                            } else if (val == 'excel') {
                              _exportExcel(records);
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'pdf',
                              child: Row(
                                children: [
                                  Icon(Icons.picture_as_pdf, color: Colors.red),
                                  SizedBox(width: 8),
                                  Text('Export PDF Report'),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'excel',
                              child: Row(
                                children: [
                                  Icon(Icons.table_chart, color: Colors.green),
                                  SizedBox(width: 8),
                                  Text('Export Excel Sheet'),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: records.isEmpty
                    ? Center(
                        child: Text(
                          'No attendance records found',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: records.length,
                        itemBuilder: (context, index) {
                          final record = records[index];
                          final name = record['employeeName'] ?? 'Unknown';
                          final date = record['date'] ?? '';
                          final timeStr = record['time'] ?? '';
                          final status = record['status'] ?? 'present';
                          final device = record['deviceModel'] ?? 'Device';
                          final battery = record['batteryLevel'] ?? 0;

                          String formattedTime = timeStr;
                          try {
                            final dt = DateTime.parse(timeStr);
                            formattedTime = DateFormat('HH:mm:ss').format(dt);
                          } catch (_) {}

                          return Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            child: ListTile(
                              leading: const CircleAvatar(
                                child: Icon(Icons.check_circle_outline, color: Colors.green),
                              ),
                              title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text(
                                'Date: $date at $formattedTime\nDevice: $device • Battery: $battery%',
                                style: const TextStyle(fontSize: 12),
                              ),
                              isThreeLine: true,
                              trailing: Chip(
                                label: Text(
                                  status.toUpperCase(),
                                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                                backgroundColor: Colors.green.withValues(alpha: 0.15),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
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
                pw.Text('Generated on: ${DateFormat('yyyy-MM-DD HH:mm:ss').format(DateTime.now())}'),
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
            content: Text('PDF generated successfully: ${file.path}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating PDF: $e'), backgroundColor: Colors.red),
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
              content: Text('Excel generated successfully: ${file.path}'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating Excel: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}
