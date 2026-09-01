import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/models/user_model.dart';
import '../../../core/services/app_translations.dart';
import '../../../core/widgets/web_layout.dart';
import '../../auth/domain/auth_provider.dart';
import '../domain/services/google_sheets_export_service.dart';
import 'widgets/web_download_stub.dart';

class GoogleSheetsAttendanceScreen extends ConsumerStatefulWidget {
  const GoogleSheetsAttendanceScreen({super.key});

  @override
  ConsumerState<GoogleSheetsAttendanceScreen> createState() =>
      _GoogleSheetsAttendanceScreenState();
}

class _GoogleSheetsAttendanceScreenState
    extends ConsumerState<GoogleSheetsAttendanceScreen> {
  final _db = FirebaseFirestore.instance;
  DateTime _selectedMonth =
      DateTime(DateTime.now().year, DateTime.now().month, 1);
  bool _isExporting = false;

  // Cache streams so they are NOT re-created on every build call,
  // which would cause infinite rebuild loops with StreamBuilder.
  late final Stream<QuerySnapshot> _usersStream;
  late final Stream<QuerySnapshot> _attendanceStream;

  @override
  void initState() {
    super.initState();
    _usersStream = _db.collection('users').snapshots();
    _attendanceStream = _db.collection('attendance').snapshots();
  }

  @override
  Widget build(BuildContext context) {
    final currentUserAsync = ref.watch(currentUserModelProvider);

    return currentUserAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(title: Text(ref.tr('googleSheetsAttendance'))),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (err, _) => Scaffold(
        appBar: AppBar(title: Text(ref.tr('googleSheetsAttendance'))),
        body: Center(child: Text('Error: $err')),
      ),
      data: (currentUser) {
        if (currentUser == null) {
          return Scaffold(
            appBar: AppBar(title: Text(ref.tr('googleSheetsAttendance'))),
            body: const Center(child: Text('User session not found')),
          );
        }

        final isAdmin = currentUser.isAdmin;

        return StreamBuilder<QuerySnapshot>(
          stream: _usersStream,
          builder: (context, usersSnap) {
            if (usersSnap.hasError) {
              return Scaffold(
                appBar: AppBar(title: Text(ref.tr('googleSheetsAttendance'))),
                body: Center(
                  child: Text('Error loading users: ${usersSnap.error}'),
                ),
              );
            }

            if (!usersSnap.hasData) {
              return Scaffold(
                appBar: AppBar(title: Text(ref.tr('googleSheetsAttendance'))),
                body: const Center(child: CircularProgressIndicator()),
              );
            }

            final allUsers = usersSnap.data!.docs
                .map(
                  (d) => UserModel.fromJson(
                    d.data() as Map<String, dynamic>,
                    d.id,
                  ),
                )
                .toList();

            final selectedMonthPrefix =
                DateFormat('yyyy-MM').format(_selectedMonth);

            return StreamBuilder<QuerySnapshot>(
              stream: _attendanceStream,
              builder: (context, attendanceSnap) {
                final attendanceMap = <String, String>{};
                if (attendanceSnap.hasData) {
                  for (final doc in attendanceSnap.data!.docs) {
                    final data = doc.data() as Map<String, dynamic>;
                    final empId = data['employeeId'] as String?;
                    final dateStr = data['date'] as String?;
                    final status = data['status'] as String?;
                    if (empId != null && dateStr != null && status != null) {
                      if (dateStr.startsWith(selectedMonthPrefix)) {
                        attendanceMap['$empId-$dateStr'] = status;
                      }
                    }
                  }
                }

                if (isAdmin) {
                  return _buildAdminView(
                    context: context,
                    currentUser: currentUser,
                    allUsers: allUsers,
                    attendanceMap: attendanceMap,
                  );
                } else {
                  return _buildManagerView(
                    context: context,
                    manager: currentUser,
                    allUsers: allUsers,
                    attendanceMap: attendanceMap,
                  );
                }
              },
            );
          },
        );
      },
    );
  }

  // ── Admin View (Tab per Manager) ─────────────────────────────────────────
  Widget _buildAdminView({
    required BuildContext context,
    required UserModel currentUser,
    required List<UserModel> allUsers,
    required Map<String, String> attendanceMap,
  }) {
    // Managers list
    final managers = allUsers.where((u) => u.isManager).toList();

    // Build manager groups
    final groups = <ManagerEmployeeGroup>[];
    for (final mgr in managers) {
      final emps = allUsers
          .where(
            (u) =>
                u.isEmployee &&
                (u.createdBy == mgr.uid || u.managerId == mgr.uid),
          )
          .toList();
      groups.add(ManagerEmployeeGroup(manager: mgr, employees: emps));
    }

    // Unassigned employees if any
    final assignedEmpIds =
        groups.expand((g) => g.employees.map((e) => e.uid)).toSet();
    final unassignedEmps = allUsers
        .where((u) => u.isEmployee && !assignedEmpIds.contains(u.uid))
        .toList();

    if (unassignedEmps.isNotEmpty) {
      final dummyManager = UserModel(
        uid: 'general_unassigned',
        email: '',
        displayName: ref.tr('generalTab'),
        role: 'manager',
      );
      groups.add(
        ManagerEmployeeGroup(
          manager: dummyManager,
          employees: unassignedEmps,
        ),
      );
    }

    if (groups.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: Text(ref.tr('googleSheetsTitle')),
          actions: [_buildMonthPickerButton(context)],
        ),
        body: Center(
          child: Text(
            ref.tr('noManagersFound'),
            style: const TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ),
      );
    }

    // Use a ValueKey based on tab count so Flutter reuses the controller
    // when count is unchanged, preventing spurious rebuilds.
    return DefaultTabController(
      key: ValueKey('admin-tabs-${groups.length}'),
      length: groups.length,
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              const Icon(
                Icons.table_chart,
                color: Colors.greenAccent,
                size: 24,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  ref.tr('googleSheetsTitle'),
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            _buildMonthPickerButton(context),
            IconButton(
              icon: _isExporting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.download),
              tooltip: ref.tr('exportGoogleSheets'),
              onPressed: _isExporting
                  ? null
                  : () => _exportToGoogleSheets(groups, attendanceMap),
            ),
          ],
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            indicatorColor: Colors.greenAccent,
            indicatorWeight: 3,
            labelStyle:
                const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            tabs: groups.map((g) {
              return Tab(
                child: Row(
                  children: [
                    const Icon(Icons.description_outlined, size: 16),
                    const SizedBox(width: 6),
                    Text(g.manager.displayName),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${g.employees.length}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
        body: WebLayout(
          child: TabBarView(
            children: groups.map((group) {
              return _GoogleSheetGrid(
                managerName: group.manager.displayName,
                employees: group.employees,
                selectedMonth: _selectedMonth,
                attendanceMap: attendanceMap,
                onCellTap: (emp, date, currentStatus) =>
                    _showAttendanceDialog(emp, date, currentStatus),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  // ── Manager View (Single Tab for Manager) ───────────────────────────────
  Widget _buildManagerView({
    required BuildContext context,
    required UserModel manager,
    required List<UserModel> allUsers,
    required Map<String, String> attendanceMap,
  }) {
    final employees = allUsers
        .where(
          (u) =>
              u.isEmployee &&
              (u.createdBy == manager.uid || u.managerId == manager.uid),
        )
        .toList();

    final group = ManagerEmployeeGroup(manager: manager, employees: employees);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.table_chart, color: Colors.greenAccent, size: 24),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${ref.tr('googleSheetsTitle')} (${manager.displayName})',
                overflow: TextOverflow.ellipsis,
                style:
                    const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        actions: [
          _buildMonthPickerButton(context),
          IconButton(
            icon: _isExporting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.download),
            tooltip: ref.tr('exportGoogleSheets'),
            onPressed: _isExporting
                ? null
                : () => _exportToGoogleSheets([group], attendanceMap),
          ),
        ],
      ),
      body: WebLayout(
        child: _GoogleSheetGrid(
          managerName: manager.displayName,
          employees: employees,
          selectedMonth: _selectedMonth,
          attendanceMap: attendanceMap,
          onCellTap: (emp, date, currentStatus) =>
              _showAttendanceDialog(emp, date, currentStatus),
        ),
      ),
    );
  }

  // ── Month Picker Button & Custom Dialog ──────────────────────────────────
  Widget _buildMonthPickerButton(BuildContext context) {
    final label = DateFormat('MMMM yyyy').format(_selectedMonth);
    return TextButton.icon(
      style: TextButton.styleFrom(foregroundColor: Colors.white),
      onPressed: () => _showMonthYearPicker(context),
      icon: const Icon(Icons.calendar_month, size: 18),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
    );
  }

  Future<void> _showMonthYearPicker(BuildContext context) async {
    int tempYear = _selectedMonth.year;
    int tempMonth = _selectedMonth.month;

    final monthNames = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];

    final picked = await showDialog<DateTime>(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: Row(
                children: [
                  const Icon(Icons.calendar_month, color: Colors.green),
                  const SizedBox(width: 8),
                  Text(ref.tr('selectMonthYear')),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Year Navigation Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left),
                        onPressed: () {
                          setDialogState(() => tempYear--);
                        },
                      ),
                      Text(
                        '$tempYear',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right),
                        onPressed: () {
                          setDialogState(() => tempYear++);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Month Grid
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: List.generate(12, (index) {
                      final monthNum = index + 1;
                      final isSelected = monthNum == tempMonth;
                      return ChoiceChip(
                        label: Text(monthNames[index].substring(0, 3)),
                        selected: isSelected,
                        selectedColor: Colors.green,
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : null,
                          fontWeight: isSelected ? FontWeight.bold : null,
                        ),
                        onSelected: (selected) {
                          if (selected) {
                            setDialogState(() => tempMonth = monthNum);
                          }
                        },
                      );
                    }),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: Text(ref.tr('cancel')),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: Colors.green),
                  onPressed: () {
                    Navigator.pop(dialogCtx, DateTime(tempYear, tempMonth, 1));
                  },
                  child: Text(ref.tr('apply')),
                ),
              ],
            );
          },
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedMonth = picked;
      });
    }
  }

  // ── Record Attendance Dialog ─────────────────────────────────────────────
  Future<void> _showAttendanceDialog(
    UserModel employee,
    DateTime date,
    String? currentStatus,
  ) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final cellDate = DateTime(date.year, date.month, date.day);

    // Guard: Cannot record attendance for future dates
    if (cellDate.isAfter(today)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${ref.tr('cannotRecordFutureDate')} (${DateFormat('yyyy-MM-dd').format(date)})',
          ),
          backgroundColor: Colors.orange.shade800,
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    final dateStr = DateFormat('yyyy-MM-dd').format(date);
    final displayDate = DateFormat('EEEE, dd MMMM yyyy').format(date);
    final docId = '${employee.uid}-$dateStr';

    // Fetch existing check-in / check-out times from Firestore
    TimeOfDay? checkIn;
    TimeOfDay? checkOut;
    try {
      final doc = await _db.collection('attendance').doc(docId).get();
      if (doc.exists) {
        final data = doc.data()!;
        final timeStr = data['time'] as String?;
        final checkoutStr = data['checkoutTime'] as String?;
        if (timeStr != null) {
          final dt = DateTime.tryParse(timeStr);
          if (dt != null) checkIn = TimeOfDay(hour: dt.hour, minute: dt.minute);
        }
        if (checkoutStr != null) {
          final dt = DateTime.tryParse(checkoutStr);
          if (dt != null) {
            checkOut = TimeOfDay(hour: dt.hour, minute: dt.minute);
          }
        }
      }
    } catch (_) {}

    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return _AttendanceEntrySheet(
          employee: employee,
          displayDate: displayDate,
          dateStr: dateStr,
          currentStatus: currentStatus,
          initialCheckIn: checkIn,
          initialCheckOut: checkOut,
          onSave: (status, newCheckIn, newCheckOut) {
            Navigator.pop(ctx);
            _saveAttendance(
              employee,
              dateStr,
              status,
              checkIn: newCheckIn,
              checkOut: newCheckOut,
            );
          },
          onClear: currentStatus != null
              ? () {
                  Navigator.pop(ctx);
                  _deleteAttendance(employee, dateStr);
                }
              : null,
          trl: ref.tr,
        );
      },
    );
  }

  Future<void> _saveAttendance(
    UserModel employee,
    String dateStr,
    String status, {
    TimeOfDay? checkIn,
    TimeOfDay? checkOut,
  }) async {
    final docId = '${employee.uid}-$dateStr';
    final now = DateTime.now();
    final dateParts = dateStr.split('-');
    final recordDate = DateTime(
      int.parse(dateParts[0]),
      int.parse(dateParts[1]),
      int.parse(dateParts[2]),
    );

    // Build check-in datetime: use provided time or existing now
    final checkInDt = checkIn != null
        ? DateTime(
            recordDate.year,
            recordDate.month,
            recordDate.day,
            checkIn.hour,
            checkIn.minute,
          )
        : now;

    // Build check-out datetime (nullable)
    final checkOutDt = checkOut != null
        ? DateTime(
            recordDate.year,
            recordDate.month,
            recordDate.day,
            checkOut.hour,
            checkOut.minute,
          )
        : null;

    try {
      final docRef = _db.collection('attendance').doc(docId);
      final docSnap = await docRef.get();
      String effectiveDeviceId = 'sheets-admin-entry';
      String effectiveDeviceModel = 'Google Sheets Entry';

      if (docSnap.exists && docSnap.data() != null) {
        final data = docSnap.data()!;
        if (data['deviceId'] != null &&
            data['deviceId'].toString().isNotEmpty &&
            data['deviceId'] != 'sheets-admin-entry') {
          effectiveDeviceId = data['deviceId'].toString();
        }
        if (data['deviceModel'] != null &&
            data['deviceModel'].toString().isNotEmpty) {
          effectiveDeviceModel = data['deviceModel'].toString();
        }
      }

      if (effectiveDeviceId == 'sheets-admin-entry') {
        try {
          final userDoc = await _db.collection('users').doc(employee.uid).get();
          if (userDoc.exists && userDoc.data() != null) {
            final boundId = userDoc.data()!['boundDeviceId'] as String?;
            if (boundId != null && boundId.isNotEmpty) {
              effectiveDeviceId = boundId;
            }
          }
        } catch (_) {}
      }

      await docRef.set(
        {
          'id': docId,
          'employeeId': employee.uid,
          'employeeName': employee.displayName,
          'date': dateStr,
          'time': status == 'absent' ? null : checkInDt.toIso8601String(),
          'checkoutTime':
              status == 'absent' ? null : checkOutDt?.toIso8601String(),
          'status': status,
          'latitude': 0.0,
          'longitude': 0.0,
          'locationAccuracy': 0.0,
          'deviceModel': effectiveDeviceModel,
          'operatingSystem': kIsWeb ? 'Web' : Platform.operatingSystem,
          'batteryLevel': 100,
          'internetStatus': 'online',
          'deviceId': effectiveDeviceId,
        },
        SetOptions(merge: true),
      );

      if (mounted) {
        final message = ref
            .tr('attendanceUpdated')
            .replaceAll('{name}', employee.displayName)
            .replaceAll('{date}', dateStr);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$message ($status)'),
            backgroundColor: status == 'present'
                ? Colors.green
                : (status == 'absent' ? Colors.redAccent : Colors.orange),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving attendance: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteAttendance(UserModel employee, String dateStr) async {
    final docId = '${employee.uid}-$dateStr';
    try {
      await _db.collection('attendance').doc(docId).delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('Cleared record for ${employee.displayName} on $dateStr'),
            backgroundColor: Colors.grey.shade700,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error clearing record: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ── Export Google Sheets Workbook ────────────────────────────────────────
  Future<void> _exportToGoogleSheets(
    List<ManagerEmployeeGroup> managerGroups,
    Map<String, String> attendanceMap,
  ) async {
    setState(() => _isExporting = true);

    try {
      final exporter = GoogleSheetsExportService();
      final bytes = exporter.generateGoogleSheetWorkbook(
        managerGroups: managerGroups,
        attendanceRecords: attendanceMap,
        month: _selectedMonth,
      );

      final monthStr = DateFormat('yyyy_MM').format(_selectedMonth);
      final fileName = 'Google_Sheets_Attendance_$monthStr.xlsx';

      if (kIsWeb) {
        downloadFileWeb(bytes, fileName);
      } else if (Platform.isAndroid || Platform.isIOS) {
        Directory? outputDir;
        if (Platform.isAndroid) {
          outputDir = await getExternalStorageDirectory();
        }
        outputDir ??= await getApplicationDocumentsDirectory();

        final filePath = '${outputDir.path}/$fileName';
        final file = File(filePath);
        await file.writeAsBytes(bytes);

        // ignore: deprecated_member_use
        await Share.shareXFiles(
          [XFile(file.path)],
          text: 'Google Sheets Attendance: $fileName',
        );
      } else {
        final chosenPath = await FilePicker.platform.saveFile(
          dialogTitle: 'Save Google Sheets Attendance Workbook',
          fileName: fileName,
          type: FileType.custom,
          allowedExtensions: ['xlsx'],
        );
        if (chosenPath != null) {
          final file = File(chosenPath);
          await file.writeAsBytes(bytes);
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ref.tr('excelGenerated')),
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
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }
}

// ── Attendance Entry Bottom Sheet ─────────────────────────────────────────────
class _AttendanceEntrySheet extends StatefulWidget {
  const _AttendanceEntrySheet({
    required this.employee,
    required this.displayDate,
    required this.dateStr,
    required this.currentStatus,
    required this.initialCheckIn,
    required this.initialCheckOut,
    required this.onSave,
    required this.trl,
    this.onClear,
  });

  final UserModel employee;
  final String displayDate;
  final String dateStr;
  final String? currentStatus;
  final TimeOfDay? initialCheckIn;
  final TimeOfDay? initialCheckOut;
  final void Function(String status, TimeOfDay? checkIn, TimeOfDay? checkOut)
      onSave;
  final VoidCallback? onClear;
  final String Function(String) trl;

  @override
  State<_AttendanceEntrySheet> createState() => _AttendanceEntrySheetState();
}

class _AttendanceEntrySheetState extends State<_AttendanceEntrySheet> {
  late TimeOfDay? _checkIn;
  late TimeOfDay? _checkOut;

  @override
  void initState() {
    super.initState();
    _checkIn = widget.initialCheckIn;
    _checkOut = widget.initialCheckOut;
  }

  String _formatTime(TimeOfDay? t) {
    if (t == null) return widget.trl('noTimeSet');
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  Future<void> _pickTime({required bool isCheckIn}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isCheckIn
          ? (_checkIn ?? TimeOfDay.now())
          : (_checkOut ?? TimeOfDay.now()),
      helpText:
          isCheckIn ? widget.trl('checkInTime') : widget.trl('checkOutTime'),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        if (isCheckIn) {
          _checkIn = picked;
        } else {
          _checkOut = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor =
        isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF5F5F5);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ───────────────────────────────────────────────────
              Row(
                children: [
                  const CircleAvatar(
                    backgroundColor: Colors.green,
                    child: Icon(Icons.table_rows, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.employee.displayName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          widget.displayDate,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const Divider(height: 28),

              // ── Status Buttons ────────────────────────────────────────────
              Text(
                'Set Attendance Status:',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      icon: const Icon(Icons.check_circle),
                      label: Text(widget.trl('markPresent')),
                      onPressed: () =>
                          widget.onSave('present', _checkIn, _checkOut),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      icon: const Icon(Icons.cancel),
                      label: Text(widget.trl('markAbsent')),
                      onPressed: () =>
                          widget.onSave('absent', _checkIn, _checkOut),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.orange,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      icon: const Icon(Icons.access_time),
                      label: Text(widget.trl('late')),
                      onPressed: () =>
                          widget.onSave('late', _checkIn, _checkOut),
                    ),
                  ),
                  if (widget.onClear != null) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.grey,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        icon: const Icon(Icons.delete_outline),
                        label: Text(widget.trl('clearAttendance')),
                        onPressed: widget.onClear,
                      ),
                    ),
                  ],
                ],
              ),

              const Divider(height: 28),

              // ── Check-In / Check-Out Times ────────────────────────────────
              Row(
                children: [
                  const Icon(Icons.schedule, color: Colors.green, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    widget.trl('attendanceTimes'),
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                widget.trl('timesOptional'),
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  // Check-In
                  Expanded(
                    child: InkWell(
                      onTap: () => _pickTime(isCheckIn: true),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _checkIn != null
                                ? Colors.green
                                : Colors.grey.shade300,
                            width: _checkIn != null ? 1.5 : 1.0,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.login,
                                  size: 14,
                                  color: _checkIn != null
                                      ? Colors.green
                                      : Colors.grey,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  widget.trl('checkInTime'),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: _checkIn != null
                                        ? Colors.green
                                        : Colors.grey.shade500,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _formatTime(_checkIn),
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'monospace',
                                color: _checkIn != null
                                    ? Colors.green
                                    : Colors.grey.shade400,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Check-Out
                  Expanded(
                    child: InkWell(
                      onTap: () => _pickTime(isCheckIn: false),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _checkOut != null
                                ? Colors.blue
                                : Colors.grey.shade300,
                            width: _checkOut != null ? 1.5 : 1.0,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.logout,
                                  size: 14,
                                  color: _checkOut != null
                                      ? Colors.blue
                                      : Colors.grey,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  widget.trl('checkOutTime'),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: _checkOut != null
                                        ? Colors.blue
                                        : Colors.grey.shade500,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _formatTime(_checkOut),
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'monospace',
                                color: _checkOut != null
                                    ? Colors.blue
                                    : Colors.grey.shade400,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              // Clear time buttons
              if (_checkIn != null || _checkOut != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (_checkIn != null)
                      TextButton.icon(
                        onPressed: () => setState(() => _checkIn = null),
                        icon: const Icon(Icons.clear, size: 14),
                        label: const Text(
                          'Clear In',
                          style: TextStyle(fontSize: 12),
                        ),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.grey,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                        ),
                      ),
                    if (_checkOut != null)
                      TextButton.icon(
                        onPressed: () => setState(() => _checkOut = null),
                        icon: const Icon(Icons.clear, size: 14),
                        label: const Text(
                          'Clear Out',
                          style: TextStyle(fontSize: 12),
                        ),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.grey,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                        ),
                      ),
                  ],
                ),
              ],

              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Google Sheet Grid Component ─────────────────────────────────────────────
class _GoogleSheetGrid extends StatelessWidget {
  const _GoogleSheetGrid({
    required this.managerName,
    required this.employees,
    required this.selectedMonth,
    required this.attendanceMap,
    required this.onCellTap,
  });

  final String managerName;
  final List<UserModel> employees;
  final DateTime selectedMonth;
  final Map<String, String> attendanceMap;
  final Function(UserModel emp, DateTime date, String? currentStatus) onCellTap;

  @override
  Widget build(BuildContext context) {
    if (employees.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'No employees assigned to $managerName',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final daysInMonth =
        DateTime(selectedMonth.year, selectedMonth.month + 1, 0).day;
    final gridBorderColor =
        isDark ? const Color(0xFF333333) : const Color(0xFFE0E0E0);
    final headerBgColor =
        isDark ? const Color(0xFF1E2922) : const Color(0xFFE8F5E9);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Formula bar header style
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF262626) : const Color(0xFFF5F5F5),
              border: Border.all(color: gridBorderColor),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(8)),
            ),
            child: Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'fx',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Page: $managerName | Total Employees: ${employees.length} | Month: ${DateFormat('MMMM yyyy').format(selectedMonth)}',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      color:
                          isDark ? Colors.grey.shade300 : Colors.grey.shade800,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

          // Scrollable Sheet Grid Table
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Table(
              defaultColumnWidth: const FixedColumnWidth(60),
              columnWidths: const {
                0: FixedColumnWidth(180), // Employee Name Sticky Col
                1: FixedColumnWidth(110), // Dept Col
              },
              border: TableBorder.all(color: gridBorderColor, width: 1),
              children: [
                // Header Row (Top row: Dates/Days)
                TableRow(
                  decoration: BoxDecoration(color: headerBgColor),
                  children: [
                    _buildHeaderCell('Employee Name'),
                    _buildHeaderCell('Department'),
                    for (int day = 1; day <= daysInMonth; day++)
                      _buildDateHeaderCell(
                        DateTime(
                          selectedMonth.year,
                          selectedMonth.month,
                          day,
                        ),
                      ),
                  ],
                ),

                // Employee Data Rows
                for (final emp in employees)
                  TableRow(
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
                    ),
                    children: [
                      // Employee Name
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              emp.displayName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              emp.email,
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey.shade500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      // Department
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: Center(
                          child: Text(
                            emp.department,
                            style: const TextStyle(fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),

                      // Attendance Cells for each date
                      for (int day = 1; day <= daysInMonth; day++)
                        _buildAttendanceCell(
                          emp: emp,
                          date: DateTime(
                            selectedMonth.year,
                            selectedMonth.month,
                            day,
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderCell(String text) {
    return Container(
      padding: const EdgeInsets.all(10),
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 12,
          color: Colors.green,
        ),
      ),
    );
  }

  Widget _buildDateHeaderCell(DateTime date) {
    final dayNum = DateFormat('dd').format(date);
    final dayName = DateFormat('E').format(date).toUpperCase();
    final isWeekend =
        date.weekday == DateTime.saturday || date.weekday == DateTime.sunday;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
      alignment: Alignment.center,
      color: isWeekend ? Colors.orange.withValues(alpha: 0.12) : null,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            dayName,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: isWeekend ? Colors.orange.shade700 : Colors.grey.shade700,
            ),
          ),
          Text(
            dayNum,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: isWeekend ? Colors.orange.shade800 : Colors.green.shade700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceCell({
    required UserModel emp,
    required DateTime date,
  }) {
    final dateStr = DateFormat('yyyy-MM-dd').format(date);
    final key = '${emp.uid}-$dateStr';
    final status = attendanceMap[key]?.toLowerCase();

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final cellDate = DateTime(date.year, date.month, date.day);
    final isFuture = cellDate.isAfter(today);

    Color bgColor = Colors.transparent;
    Widget iconWidget = const Text('—', style: TextStyle(color: Colors.grey));

    if (status == 'present') {
      bgColor = Colors.green.withValues(alpha: 0.15);
      iconWidget =
          const Icon(Icons.check_circle, color: Colors.green, size: 20);
    } else if (status == 'absent') {
      bgColor = Colors.red.withValues(alpha: 0.15);
      iconWidget = const Icon(Icons.cancel, color: Colors.redAccent, size: 20);
    } else if (status == 'late') {
      bgColor = Colors.orange.withValues(alpha: 0.15);
      iconWidget =
          const Icon(Icons.access_time, color: Colors.orange, size: 20);
    } else if (!isFuture) {
      // Empty cell for past/today date -> render in RED as an absence!
      bgColor = Colors.red.withValues(alpha: 0.18);
      iconWidget = const Icon(Icons.cancel, color: Colors.redAccent, size: 20);
    } else {
      // Future date cell
      iconWidget = Text('—', style: TextStyle(color: Colors.grey.shade600));
    }

    return InkWell(
      onTap: () => onCellTap(emp, date, status),
      child: Container(
        height: 48,
        color: bgColor,
        alignment: Alignment.center,
        child: iconWidget,
      ),
    );
  }
}
