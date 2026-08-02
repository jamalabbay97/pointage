import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart' as xl;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:universal_io/io.dart';


class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _db = FirebaseFirestore.instance;
  String _searchQuery = '';
  String _statusFilter = 'All';

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance History'),
      ),
      body: _isWide
          ? Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: _buildBody(user),
              ),
            )
          : _buildBody(user),
    );
  }

  static bool get _isWide =>
      kIsWeb ||
      defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.linux;

  Widget _buildBody(User? user) {
    return StreamBuilder<QuerySnapshot>(
        stream: _db
            .collection('attendance')
            .where('employeeId', isEqualTo: user?.uid ?? '')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error loading history: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ?? [];
          var records = docs.map((d) => d.data() as Map<String, dynamic>).toList();

          // Sort descending by date/time
          records.sort((a, b) {
            final t1 = a['time'] as String? ?? '';
            final t2 = b['time'] as String? ?? '';
            return t2.compareTo(t1);
          });

          if (_searchQuery.isNotEmpty) {
            records = records.where((r) {
              final date = (r['date'] as String? ?? '').toLowerCase();
              final device = (r['deviceModel'] as String? ?? '').toLowerCase();
              return date.contains(_searchQuery.toLowerCase()) || device.contains(_searchQuery.toLowerCase());
            }).toList();
          }

          if (_statusFilter != 'All') {
            records = records.where((r) {
              final status = (r['status'] as String? ?? '').toLowerCase();
              return status == _statusFilter.toLowerCase();
            }).toList();
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    SearchBar(
                      hintText: 'Search by date or device model...',
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
                          tooltip: 'Export',
                          onSelected: (val) {
                            if (val == 'pdf') {
                              _exportPdf(records, user?.displayName ?? 'Employee');
                            } else if (val == 'excel') {
                              _exportExcel(records, user?.displayName ?? 'Employee');
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'pdf',
                              child: Row(
                                children: [
                                  Icon(Icons.picture_as_pdf, color: Colors.red),
                                  SizedBox(width: 8),
                                  Text('Export PDF'),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'excel',
                              child: Row(
                                children: [
                                  Icon(Icons.table_chart, color: Colors.green),
                                  SizedBox(width: 8),
                                  Text('Export Excel'),
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
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.history_outlined, size: 64, color: Colors.grey.shade400),
                            const SizedBox(height: 16),
                            Text(
                              'No attendance history records found',
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: records.length,
                        itemBuilder: (context, index) {
                          final record = records[index];
                          final date = record['date'] ?? '';
                          final timeStr = record['time'] ?? '';
                          final status = record['status'] ?? 'present';
                          final device = record['deviceModel'] ?? 'Mobile Device';
                          final battery = record['batteryLevel'] ?? 0;
                          final lat = record['latitude'] ?? 0.0;
                          final lng = record['longitude'] ?? 0.0;

                          String formattedTime = timeStr;
                          try {
                            formattedTime = DateFormat('HH:mm:ss').format(DateTime.parse(timeStr));
                          } catch (_) {}

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              leading: const CircleAvatar(
                                backgroundColor: Color(0xFFDCFCE7),
                                child: Icon(Icons.verified, color: Colors.green),
                              ),
                              title: Text(
                                'Date: $date at $formattedTime',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Text(
                                'GPS: ${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}\nDevice: $device ($battery% battery)',
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

  Future<void> _exportPdf(List<Map<String, dynamic>> records, String employeeName) async {
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
                    'Personal Attendance Statement - $employeeName',
                    style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
                  ),
                ),
                pw.SizedBox(height: 10),
                pw.Text('Generated: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())}'),
                pw.Text('Total Verified Days: ${records.length}'),
                pw.SizedBox(height: 20),
                pw.TableHelper.fromTextArray(
                  headers: ['Date', 'Time', 'Status', 'Device Model', 'Battery'],
                  data: records.map((r) {
                    final timeStr = r['time'] ?? '';
                    String ft = timeStr;
                    try {
                      ft = DateFormat('HH:mm:ss').format(DateTime.parse(timeStr));
                    } catch (_) {}
                    return [
                      r['date'] ?? 'N/A',
                      ft,
                      (r['status'] as String? ?? 'present').toUpperCase(),
                      r['deviceModel'] ?? 'N/A',
                      '${r['batteryLevel'] ?? 0}%',
                    ];
                  }).toList(),
                ),
              ],
            );
          },
        ),
      );

      final outputDir = Directory.systemTemp.path;
      final file = File('$outputDir/My_Attendance_${DateTime.now().millisecondsSinceEpoch}.pdf');
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

  Future<void> _exportExcel(List<Map<String, dynamic>> records, String employeeName) async {
    try {
      final excel = xl.Excel.createExcel();
      final sheet = excel['My Attendance'];

      sheet.appendRow([
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
      final file = File('$outputDir/My_Attendance_${DateTime.now().millisecondsSinceEpoch}.xlsx');
      final bytes = excel.encode();
      if (bytes != null) {
        await file.writeAsBytes(bytes);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Excel sheet saved: ${file.path}'),
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
