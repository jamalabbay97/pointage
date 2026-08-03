import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart' as xl;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:universal_io/io.dart';

import '../../../core/models/user_model.dart';
import '../../../core/services/app_translations.dart';
import '../../auth/domain/auth_provider.dart';

enum _PeriodFilter { day, week, month, year }

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
  _PeriodFilter _periodFilter = _PeriodFilter.month;
  DateTime _selectedDate = DateTime.now();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authUser = FirebaseAuth.instance.currentUser;
    final userModelAsync = ref.watch(currentUserModelProvider);

    return Scaffold(
      appBar: AppBar(title: Text(ref.tr('reportsAnalytics'))),
      body: userModelAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Error loading user: $error')),
        data: (currentUser) {
          if (authUser == null || currentUser == null) {
            return Center(child: Text(ref.tr('noHistoryFound')));
          }
          final body = _buildBody(authUser, currentUser);
          return _isWide
              ? Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 920),
                    child: body,
                  ),
                )
              : body;
        },
      ),
    );
  }

  static bool get _isWide =>
      kIsWeb ||
      defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.linux;

  Widget _buildBody(User authUser, UserModel currentUser) {
    return StreamBuilder<QuerySnapshot>(
      stream: _db.collection('users').snapshots(),
      builder: (context, usersSnapshot) {
        if (usersSnapshot.hasError) {
          return Center(
            child: Text('Error loading users: ${usersSnapshot.error}'),
          );
        }
        if (usersSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final allUsers = usersSnapshot.data?.docs
                .map((doc) => _HistoryUser.fromDoc(doc))
                .where((user) => user.status != 'disabled')
                .toList() ??
            [];
        final visibleUsers = _visibleUsers(allUsers, currentUser, authUser);
        final range = _selectedRange();

        return StreamBuilder<QuerySnapshot>(
          stream: _db.collection('attendance').snapshots(),
          builder: (context, attendanceSnapshot) {
            if (attendanceSnapshot.hasError) {
              return Center(
                child:
                    Text('Error loading history: ${attendanceSnapshot.error}'),
              );
            }
            if (attendanceSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final rawRecords = attendanceSnapshot.data?.docs
                    .map((doc) => doc.data() as Map<String, dynamic>)
                    .toList() ??
                [];
            final rows = _buildRows(visibleUsers, rawRecords, range);
            final filteredRows = _filterRows(rows);
            final stats = _stats(rows, visibleUsers.length, range);

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      SearchBar(
                        controller: _searchController,
                        hintText:
                            'Search by employee, date, device, or status...',
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
                        onChanged: (val) =>
                            setState(() => _searchQuery = val.trim()),
                      ),
                      const SizedBox(height: 12),
                      _buildPeriodFilters(range),
                      const SizedBox(height: 12),
                      _buildStatusAndExport(
                        filteredRows,
                        'Supervisors',
                      ),
                      const SizedBox(height: 12),
                      _buildStats(stats),
                    ],
                  ),
                ),
                Expanded(child: _buildList(filteredRows)),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildPeriodFilters(_DateRange range) {
    return Row(
      children: [
        DropdownButton<_PeriodFilter>(
          value: _periodFilter,
          items: const [
            DropdownMenuItem(value: _PeriodFilter.day, child: Text('Day')),
            DropdownMenuItem(value: _PeriodFilter.week, child: Text('Week')),
            DropdownMenuItem(value: _PeriodFilter.month, child: Text('Month')),
            DropdownMenuItem(value: _PeriodFilter.year, child: Text('Year')),
          ],
          onChanged: (value) {
            if (value != null) setState(() => _periodFilter = value);
          },
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(range.label, overflow: TextOverflow.ellipsis)),
        TextButton.icon(
          icon: const Icon(Icons.calendar_month),
          label: const Text('Change'),
          onPressed: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: _selectedDate,
              firstDate: DateTime(DateTime.now().year, DateTime.now().month),
              lastDate: DateTime.now(),
            );
            if (picked != null) setState(() => _selectedDate = picked);
          },
        ),
      ],
    );
  }

  Widget _buildStatusAndExport(List<_HistoryRow> rows, String employeeName) {
    return Row(
      children: [
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: ['All', 'Present', 'Late', 'Absent'].map((statusKey) {
                final label = statusKey == 'All' ? ref.tr('all') : statusKey;
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
        PopupMenuButton<String>(
          icon: const Icon(Icons.download_rounded),
          tooltip: ref.tr('export'),
          onSelected: (val) {
            final records = rows.map((row) => row.toExportMap()).toList();
            if (val == 'pdf') _exportPdf(records, employeeName);
            if (val == 'excel') _exportExcel(records, employeeName);
          },
          itemBuilder: (context) => [
            PopupMenuItem(value: 'pdf', child: Text(ref.tr('exportPdf'))),
            PopupMenuItem(value: 'excel', child: Text(ref.tr('exportExcel'))),
          ],
        ),
      ],
    );
  }

  Widget _buildStats(_HistoryStats stats) {
    Widget tile(String label, int value) => Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                children: [
                  Text(
                    '$value',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(label, textAlign: TextAlign.center),
                ],
              ),
            ),
          ),
        );
    return Row(
      children: [
        tile('Working days', stats.workingDays),
        tile('Absent days', stats.absentDays),
        tile('Records', stats.attendanceRecords),
      ],
    );
  }

  Widget _buildList(List<_HistoryRow> rows) {
    if (rows.isEmpty) {
      return Center(child: Text(ref.tr('noHistoryFound')));
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: rows.length,
      itemBuilder: (context, index) {
        final row = rows[index];
        final isAbsent = row.status == 'absent';
        final isLate = row.status == 'late';
        final color =
            isAbsent ? Colors.red : (isLate ? Colors.orange : Colors.green);
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: color.withValues(alpha: 0.15),
              child: Icon(
                isAbsent
                    ? Icons.cancel
                    : (isLate ? Icons.access_time_filled : Icons.verified_user),
                color: color,
              ),
            ),
            title: Text(
              row.employeeName,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            subtitle: Text(
              'Date: ${row.date}\nAttendance time: ${row.attendanceTime}\nCheck-out time: ${row.checkoutTime}\n${isAbsent ? 'No attendance record' : 'Device: ${row.device} (${row.battery}%)'}',
              style: const TextStyle(fontSize: 12),
            ),
            isThreeLine: true,
            trailing: Chip(
              label: Text(
                row.status.toUpperCase(),
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
              backgroundColor: color.withValues(alpha: 0.15),
            ),
          ),
        );
      },
    );
  }

  List<_HistoryUser> _visibleUsers(
    List<_HistoryUser> users,
    UserModel currentUser,
    User authUser,
  ) {
    if (currentUser.isAdmin) {
      return users.where((user) => !user.isAdmin).toList();
    }
    if (currentUser.isManager) {
      return users
          .where(
            (user) =>
                user.uid == authUser.uid ||
                user.createdBy == authUser.uid ||
                user.managerId == authUser.uid ||
                user.reportsTo == authUser.uid,
          )
          .toList();
    }
    return users.where((user) => user.uid == authUser.uid).toList();
  }

  _DateRange _selectedRange() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final monthFloor = DateTime(now.year, now.month);
    var start =
        DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    var end = start;
    switch (_periodFilter) {
      case _PeriodFilter.day:
        break;
      case _PeriodFilter.week:
        start = start.subtract(Duration(days: start.weekday - 1));
        end = start.add(const Duration(days: 6));
        break;
      case _PeriodFilter.month:
        start = DateTime(_selectedDate.year, _selectedDate.month);
        end = DateTime(_selectedDate.year, _selectedDate.month + 1, 0);
        break;
      case _PeriodFilter.year:
        start = DateTime(_selectedDate.year);
        end = DateTime(_selectedDate.year, 12, 31);
        break;
    }
    if (start.isBefore(monthFloor)) start = monthFloor;
    if (start.isAfter(today)) start = today;
    if (end.isAfter(today)) end = today;
    if (end.isBefore(start)) end = start;
    return _DateRange(
      start,
      end,
      '${DateFormat.yMMMd().format(start)} - ${DateFormat.yMMMd().format(end)}',
    );
  }

  List<_HistoryRow> _buildRows(
    List<_HistoryUser> users,
    List<Map<String, dynamic>> records,
    _DateRange range,
  ) {
    final userIds = users.map((user) => user.uid).toSet();
    final byUserDate = <String, Map<String, dynamic>>{};
    for (final record in records) {
      final employeeId = record['employeeId'] as String? ?? '';
      final date = record['date'] as String? ?? '';
      final parsed = DateTime.tryParse(date);
      if (!userIds.contains(employeeId) ||
          parsed == null ||
          !_inRange(parsed, range)) {
        continue;
      }
      byUserDate['$employeeId|$date'] = record;
    }

    final rows = <_HistoryRow>[];
    for (final day in _days(range)) {
      if (day.weekday == DateTime.saturday || day.weekday == DateTime.sunday) {
        continue;
      }
      final date = DateFormat('yyyy-MM-dd').format(day);
      for (final user in users) {
        final record = byUserDate['${user.uid}|$date'];
        rows.add(_HistoryRow.from(user, date, record));
      }
    }
    rows.sort(
      (a, b) => '${b.date} ${b.attendanceTime}'
          .compareTo('${a.date} ${a.attendanceTime}'),
    );
    return rows;
  }

  List<_HistoryRow> _filterRows(List<_HistoryRow> rows) {
    var filtered = rows;
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      filtered = filtered.where((row) => row.searchText.contains(q)).toList();
    }
    if (_statusFilter != 'All') {
      filtered = filtered
          .where((row) => row.status == _statusFilter.toLowerCase())
          .toList();
    }
    return filtered;
  }

  _HistoryStats _stats(
    List<_HistoryRow> rows,
    int visibleUserCount,
    _DateRange range,
  ) {
    final workingDays = _workingDays(range);
    final attendanceRecords =
        rows.where((row) => row.status != 'absent').length;
    final expected = workingDays * visibleUserCount;
    return _HistoryStats(
      workingDays: workingDays,
      absentDays: expected - attendanceRecords,
      attendanceRecords: attendanceRecords,
    );
  }

  Iterable<DateTime> _days(_DateRange range) sync* {
    for (var day = range.start;
        !day.isAfter(range.end);
        day = day.add(const Duration(days: 1))) {
      yield day;
    }
  }

  int _workingDays(_DateRange range) => _days(range)
      .where(
        (day) =>
            day.weekday != DateTime.saturday && day.weekday != DateTime.sunday,
      )
      .length;
  bool _inRange(DateTime day, _DateRange range) =>
      !day.isBefore(range.start) && !day.isAfter(range.end);

  Future<void> _exportPdf(
    List<Map<String, dynamic>> records,
    String employeeName,
  ) async {
    try {
      final pdf = pw.Document();
      pdf.addPage(
        pw.Page(
          build: (_) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Header(
                level: 0,
                child: pw.Text(
                  'Attendance Reports & Analytics - $employeeName',
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.Text(
                'Generated: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())}',
              ),
              pw.Text('Total Rows: ${records.length}'),
              pw.SizedBox(height: 20),
              pw.TableHelper.fromTextArray(
                headers: [
                  'Employee',
                  'Date',
                  'Attendance',
                  'Check-out',
                  'Status',
                ],
                data: records
                    .map(
                      (r) => [
                        r['employeeName'] ?? 'N/A',
                        r['date'] ?? 'N/A',
                        r['time'] ?? 'N/A',
                        r['checkoutTime'] ?? 'N/A',
                        r['status'] ?? 'N/A',
                      ],
                    )
                    .toList(),
              ),
            ],
          ),
        ),
      );
      final file = File(
        '${Directory.systemTemp.path}/Attendance_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
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
          SnackBar(
            content: Text('${ref.tr('errorGenerating')}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _exportExcel(
    List<Map<String, dynamic>> records,
    String employeeName,
  ) async {
    try {
      final excel = xl.Excel.createExcel();
      final sheet = excel['Attendance'];
      sheet.appendRow(
        [
          'Employee Name',
          'Date',
          'Attendance Time',
          'Check-out Time',
          'Status',
          'Device Model',
        ].map(xl.TextCellValue.new).toList(),
      );
      for (final r in records) {
        sheet.appendRow(
          [
            'employeeName',
            'date',
            'time',
            'checkoutTime',
            'status',
            'deviceModel',
          ].map((key) => xl.TextCellValue(r[key]?.toString() ?? '')).toList(),
        );
      }
      final bytes = excel.encode();
      if (bytes != null) {
        final file = File(
          '${Directory.systemTemp.path}/Attendance_${DateTime.now().millisecondsSinceEpoch}.xlsx',
        );
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
          SnackBar(
            content: Text('${ref.tr('errorGenerating')}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

class _HistoryUser {
  const _HistoryUser({
    required this.uid,
    required this.displayName,
    required this.status,
    required this.createdBy,
    required this.managerId,
    required this.reportsTo,
    required this.role,
  });
  final String uid, displayName, status, createdBy, managerId, reportsTo, role;
  bool get isAdmin => role.trim().toLowerCase() == 'admin';
  factory _HistoryUser.fromDoc(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    String field(String key) => data[key] as String? ?? '';
    return _HistoryUser(
      uid: doc.id,
      displayName:
          field('displayName').isEmpty ? 'Employee' : field('displayName'),
      status: field('status'),
      createdBy: field('createdBy'),
      managerId: field('managerId'),
      reportsTo: field('reportsTo'),
      role: field('role'),
    );
  }
}

class _HistoryRow {
  const _HistoryRow({
    required this.employeeName,
    required this.date,
    required this.attendanceTime,
    required this.checkoutTime,
    required this.status,
    required this.device,
    required this.battery,
  });
  final String employeeName, date, attendanceTime, checkoutTime, status, device;
  final Object battery;

  factory _HistoryRow.from(
    _HistoryUser user,
    String date,
    Map<String, dynamic>? record,
  ) {
    if (record == null) {
      return _HistoryRow(
        employeeName: user.displayName,
        date: date,
        attendanceTime: '—',
        checkoutTime: '—',
        status: 'absent',
        device: '—',
        battery: '—',
      );
    }
    String time(Object? value) {
      final raw = value?.toString() ?? '';
      final parsed = DateTime.tryParse(raw);
      return parsed == null
          ? (raw.isEmpty ? '—' : raw)
          : DateFormat('HH:mm:ss').format(parsed);
    }

    return _HistoryRow(
      employeeName: _displayName(record['employeeName'], user.displayName),
      date: date,
      attendanceTime: time(record['time']),
      checkoutTime: time(record['checkoutTime']),
      status: (record['status'] as String? ?? 'present').toLowerCase(),
      device: record['deviceModel'] as String? ?? 'Mobile Device',
      battery: record['batteryLevel'] ?? 0,
    );
  }

  static String _displayName(Object? value, String fallback) {
    final name = value?.toString().trim() ?? '';
    return name.isEmpty ? fallback : name;
  }

  String get searchText =>
      '$employeeName $date $attendanceTime $checkoutTime $status $device'
          .toLowerCase();
  Map<String, dynamic> toExportMap() => {
        'employeeName': employeeName,
        'date': date,
        'time': attendanceTime,
        'checkoutTime': checkoutTime,
        'status': status,
        'deviceModel': device,
      };
}

class _DateRange {
  const _DateRange(this.start, this.end, this.label);
  final DateTime start, end;
  final String label;
}

class _HistoryStats {
  const _HistoryStats({
    required this.workingDays,
    required this.absentDays,
    required this.attendanceRecords,
  });
  final int workingDays, absentDays, attendanceRecords;
}
