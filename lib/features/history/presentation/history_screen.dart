import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart' as xl;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:universal_io/io.dart';

import '../../../core/services/app_translations.dart';
import '../../auth/domain/auth_provider.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
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
    final user = FirebaseAuth.instance.currentUser;
    final isAdminOrManager = ref.watch(isAdminOrManagerProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(ref.tr('attendanceHistory')),
      ),
      body: _isWide
          ? Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: _buildBody(user, isAdminOrManager),
              ),
            )
          : _buildBody(user, isAdminOrManager),
    );
  }

  static bool get _isWide =>
      kIsWeb ||
      defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.linux;

  Widget _buildBody(User? user, bool isAdminOrManager) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              SearchBar(
                controller: _searchController,
                hintText: 'Search by employee, date, device, or status...',
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
                            _exportPdf(records, user?.displayName ?? 'Employee');
                          } else if (val == 'excel') {
                            _exportExcel(records, user?.displayName ?? 'Employee');
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
                return Center(child: Text('Error loading history: ${snapshot.error}'));
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final docs = snapshot.data?.docs ?? [];
              var records = docs.map((d) => d.data() as Map<String, dynamic>).toList();

              // Filter records for logged in user (or allow all if admin/manager)
              if (!isAdminOrManager && user != null) {
                records = records.where((r) {
                  final empId = r['employeeId'] as String? ?? '';
                  final empName = (r['employeeName'] as String? ?? '').toLowerCase();
                  final userEmail = (user.email ?? '').toLowerCase();
                  final userName = (user.displayName ?? '').toLowerCase();
                  return empId == user.uid ||
                      (userName.isNotEmpty && empName.contains(userName)) ||
                      (userEmail.isNotEmpty && empName.contains(userEmail.split('@').first));
                }).toList();
              }

              // Sort descending by date/time
              records.sort((a, b) {
                final t1 = a['time'] as String? ?? '';
                final t2 = b['time'] as String? ?? '';
                return t2.compareTo(t1);
              });

              // Search Query Filter across multi-fields
              if (_searchQuery.isNotEmpty) {
                records = records.where((r) {
                  final date = (r['date'] as String? ?? '').toLowerCase();
                  final device = (r['deviceModel'] as String? ?? '').toLowerCase();
                  final status = (r['status'] as String? ?? '').toLowerCase();
                  final name = (r['employeeName'] as String? ?? '').toLowerCase();
                  final empId = (r['employeeId'] as String? ?? '').toLowerCase();
                  final q = _searchQuery.toLowerCase();
                  return date.contains(q) ||
                      device.contains(q) ||
                      status.contains(q) ||
                      name.contains(q) ||
                      empId.contains(q);
                }).toList();
              }

              // Status Filter Chip
              if (_statusFilter != 'All') {
                records = records.where((r) {
                  final status = (r['status'] as String? ?? '').toLowerCase();
                  return status == _statusFilter.toLowerCase();
                }).toList();
              }

              if (records.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.history_outlined, size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      Text(
                        ref.tr('noHistoryFound'),
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: records.length,
                itemBuilder: (context, index) {
                  final record = records[index];
                  final employeeName = record['employeeName'] as String? ?? 'Employee';
                  final date = record['date'] as String? ?? '';
                  final timeStr = record['time'] as String? ?? '';
                  final status = (record['status'] as String? ?? 'present').toLowerCase();
                  final device = record['deviceModel'] as String? ?? 'Mobile Device';
                  final battery = record['batteryLevel'] ?? 0;
                  final lat = (record['latitude'] as num?)?.toDouble() ?? 0.0;
                  final lng = (record['longitude'] as num?)?.toDouble() ?? 0.0;

                  String formattedTime = timeStr;
                  try {
                    formattedTime = DateFormat('HH:mm:ss').format(DateTime.parse(timeStr));
                  } catch (_) {}

                  final isLate = status == 'late';
                  final statusLabel = isLate ? ref.tr('late') : ref.tr('present');

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: isLate
                            ? Colors.orange.withValues(alpha: 0.2)
                            : const Color(0xFFDCFCE7),
                        child: Icon(
                          isLate ? Icons.access_time_filled : Icons.verified_user,
                          color: isLate ? Colors.orange : Colors.green,
                        ),
                      ),
                      title: Text(
                        employeeName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      subtitle: Text(
                        '${ref.tr('date')}: $date at $formattedTime\nGPS: ${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)} • ${ref.tr('device')}: $device ($battery%)',
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
              );
            },
          ),
        ),
      ],
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
                  headers: ['Employee', 'Date', 'Time', 'Status', 'Device Model', 'Battery'],
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

  Future<void> _exportExcel(List<Map<String, dynamic>> records, String employeeName) async {
    try {
      final excel = xl.Excel.createExcel();
      final sheet = excel['My Attendance'];

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
      final file = File('$outputDir/My_Attendance_${DateTime.now().millisecondsSinceEpoch}.xlsx');
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
