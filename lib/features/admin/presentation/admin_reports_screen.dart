import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/models/user_model.dart';
import '../../../core/services/app_translations.dart';
import '../../auth/domain/auth_provider.dart';
import 'widgets/export_attendance_dialog.dart';

enum _PeriodFilter { day, week, month, year }

enum _ViewMode { list, employee }

class AdminReportsScreen extends ConsumerStatefulWidget {
  const AdminReportsScreen({super.key});

  @override
  ConsumerState<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends ConsumerState<AdminReportsScreen> {
  final _db = FirebaseFirestore.instance;
  final ValueNotifier<String> _searchQueryNotifier = ValueNotifier('');
  String _statusFilter = 'All';
  _PeriodFilter _periodFilter = _PeriodFilter.month;
  DateTime _selectedDate = DateTime.now();

  _ViewMode _viewMode = _ViewMode.list;
  String? _selectedEmployeeId;

  @override
  void dispose() {
    _searchQueryNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authUser = FirebaseAuth.instance.currentUser;
    final userModelAsync = ref.watch(currentUserModelProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(ref.tr('reportsAnalytics')),
        elevation: 0,
        centerTitle: true,
      ),
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

  Stream<QuerySnapshot> _usersStream(UserModel currentUser, String authUid) {
    if (currentUser.isManager) {
      return _db
          .collection('users')
          .where('createdBy', isEqualTo: authUid)
          .snapshots();
    }
    return _db.collection('users').snapshots();
  }

  Widget _buildBody(User authUser, UserModel currentUser) {
    return StreamBuilder<QuerySnapshot>(
      stream: _usersStream(currentUser, authUser.uid),
      builder: (context, usersSnapshot) {
        if (usersSnapshot.hasError) {
          return _buildErrorState(
            'Error loading users: ${usersSnapshot.error}',
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
        if (currentUser.isManager &&
            currentUser.status.trim().toLowerCase() != 'disabled' &&
            !allUsers.any((user) => user.uid == authUser.uid)) {
          allUsers.insert(0, _HistoryUser.fromUserModel(currentUser));
        }
        final visibleUsers = _visibleUsers(allUsers, currentUser, authUser);
        final range = _selectedRange();

        final exportableUsers = usersSnapshot.data?.docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return UserModel.fromJson(data, doc.id);
            }).where((u) {
              if (currentUser.isAdmin) return !u.isAdmin && !u.isManager;
              if (currentUser.isManager) {
                return !u.isManager &&
                    (u.createdBy == authUser.uid ||
                        u.managerId == authUser.uid);
              }
              return u.uid == authUser.uid;
            }).toList() ??
            [];

        return StreamBuilder<QuerySnapshot>(
          stream: _db.collection('attendance').snapshots(),
          builder: (context, attendanceSnapshot) {
            if (attendanceSnapshot.hasError) {
              return _buildErrorState('Unable to load attendance records');
            }
            if (attendanceSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final rawRecords = attendanceSnapshot.data?.docs
                    .map((doc) => doc.data() as Map<String, dynamic>)
                    .toList() ??
                [];
            final rows = _buildRows(visibleUsers, rawRecords, range);
            final stats = _stats(rows, visibleUsers, range);

            return Column(
              children: [
                _buildHeader(visibleUsers, exportableUsers, range),
                Expanded(
                  child: ValueListenableBuilder<String>(
                    valueListenable: _searchQueryNotifier,
                    builder: (context, searchQuery, _) {
                      final filteredRows = _filterRows(rows, searchQuery);

                      if (_viewMode == _ViewMode.employee) {
                        return _buildEmployeeView(
                          filteredRows,
                          visibleUsers,
                          range,
                        );
                      }
                      return _buildListView(
                        filteredRows,
                        stats,
                        visibleUsers,
                        range,
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 16),
          Text(message, style: const TextStyle(fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildHeader(
    List<_HistoryUser> visibleUsers,
    List<UserModel> exportableUsers,
    _DateRange range,
  ) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _PersistentSearchBar(
                  key: const ValueKey('reports-search'),
                  onChanged: (val) => _searchQueryNotifier.value = val.trim(),
                  onClear: () => _searchQueryNotifier.value = '',
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                icon: const Icon(Icons.filter_list),
                label: const Text('Filters'),
                onPressed: () => _showFilterBottomSheet(visibleUsers),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                icon: const Icon(Icons.download_rounded),
                tooltip: ref.tr('exportAttendanceData'),
                onPressed: () {
                  ExportAttendanceDialog.show(context, exportableUsers);
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              SegmentedButton<_ViewMode>(
                segments: const [
                  ButtonSegment(
                    value: _ViewMode.list,
                    icon: Icon(Icons.list),
                    label: Text('List'),
                  ),
                  ButtonSegment(
                    value: _ViewMode.employee,
                    icon: Icon(Icons.person),
                    label: Text('Employee'),
                  ),
                ],
                selected: {_viewMode},
                onSelectionChanged: (Set<_ViewMode> newSelection) {
                  setState(() => _viewMode = newSelection.first);
                },
              ),
              Text(
                range.label,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showFilterBottomSheet(List<_HistoryUser> visibleUsers) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 24,
                right: 24,
                top: 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Filters',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Employee',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String?>(
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    initialValue: _selectedEmployeeId,
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('All Employees'),
                      ),
                      ...visibleUsers.map(
                        (u) => DropdownMenuItem(
                          value: u.uid,
                          child: Text(u.displayName),
                        ),
                      ),
                    ],
                    onChanged: (val) =>
                        setSheetState(() => _selectedEmployeeId = val),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Status',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children:
                        ['All', 'Present', 'Late', 'Absent'].map((statusKey) {
                      final label =
                          statusKey == 'All' ? ref.tr('all') : statusKey;
                      return ChoiceChip(
                        label: Text(label),
                        selected: _statusFilter == statusKey,
                        onSelected: (selected) {
                          if (selected) {
                            setSheetState(() => _statusFilter = statusKey);
                          }
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Date Range',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<_PeriodFilter>(
                          decoration: InputDecoration(
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                          initialValue: _periodFilter,
                          items: const [
                            DropdownMenuItem(
                              value: _PeriodFilter.day,
                              child: Text('Day'),
                            ),
                            DropdownMenuItem(
                              value: _PeriodFilter.week,
                              child: Text('Week'),
                            ),
                            DropdownMenuItem(
                              value: _PeriodFilter.month,
                              child: Text('Month'),
                            ),
                            DropdownMenuItem(
                              value: _PeriodFilter.year,
                              child: Text('Year'),
                            ),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setSheetState(() => _periodFilter = val);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      IconButton.filledTonal(
                        icon: const Icon(Icons.calendar_month),
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _selectedDate,
                            firstDate: DateTime(DateTime.now().year - 5),
                            lastDate: DateTime.now(),
                          );
                          if (picked != null) {
                            setSheetState(() => _selectedDate = picked);
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () {
                            setSheetState(() {
                              _selectedEmployeeId = null;
                              _statusFilter = 'All';
                              _periodFilter = _PeriodFilter.month;
                              _selectedDate = DateTime.now();
                            });
                          },
                          child: const Text(
                            'Reset',
                            style: TextStyle(fontSize: 16),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () {
                            Navigator.pop(context);
                            setState(() {});
                          },
                          child: const Text(
                            'Apply',
                            style: TextStyle(fontSize: 16),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTeamOverview(
    _HistoryStats stats,
    int totalEmployees,
    _DateRange range,
  ) {
    Widget tile(String label, int value, Color color) => Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withValues(alpha: 0.2)),
            ),
            child: Column(
              children: [
                Text(
                  '$value',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 24,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'TEAM OVERVIEW',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              tile('Employees', totalEmployees, Colors.blue),
              tile('Present', stats.presentDays, Colors.green),
              tile('Late', stats.lateDays, Colors.orange),
              if (range.period == _PeriodFilter.day)
                tile('Absent', stats.absentDays, Colors.red),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildListView(
    List<_HistoryRow> rows,
    _HistoryStats stats,
    List<_HistoryUser> visibleUsers,
    _DateRange range,
  ) {
    if (rows.isEmpty) {
      return _buildEmptyState();
    }

    final grouped = _groupByDate(rows);
    final dates = grouped.keys.toList();

    return ListView.builder(
      itemCount: dates.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return _buildTeamOverview(stats, visibleUsers.length, range);
        }

        final date = dates[index - 1];
        final dayRows = grouped[date]!;

        DateTime? parsedDate = DateTime.tryParse(date);
        String headerText = date;
        if (parsedDate != null) {
          headerText =
              DateFormat('EEEE, MMMM d').format(parsedDate).toUpperCase();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    headerText,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Colors.grey,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Divider(color: Colors.grey.withValues(alpha: 0.3)),
                ],
              ),
            ),
            ...dayRows.map((row) => _buildCompactRow(row, showEmployee: true)),
          ],
        );
      },
    );
  }

  Widget _buildEmployeeView(
    List<_HistoryRow> rows,
    List<_HistoryUser> visibleUsers,
    _DateRange range,
  ) {
    if (_selectedEmployeeId == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.person_search, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            const Text(
              'Select an employee to view their details',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => _showFilterBottomSheet(visibleUsers),
              child: const Text('Select Employee'),
            ),
          ],
        ),
      );
    }

    final employeeRows =
        rows.where((r) => r.employeeId == _selectedEmployeeId).toList();
    final user = visibleUsers.firstWhere(
      (u) => u.uid == _selectedEmployeeId,
      orElse: () => const _HistoryUser(
        uid: '',
        displayName: 'Unknown',
        status: '',
        createdBy: '',
        managerId: '',
        reportsTo: '',
        role: '',
        scheduleType: 'standard',
      ),
    );

    final present = employeeRows
        .where((r) => r.status == 'present' || r.status == 'late')
        .length;
    final late = employeeRows.where((r) => r.status == 'late').length;

    final expectedDays = _workingDays(range, user.scheduleType);
    final absent = (expectedDays - present).clamp(0, expectedDays).toInt();

    if (employeeRows.isEmpty) {
      return Column(
        children: [
          _buildEmployeeSummary(user, present, late, absent),
          Expanded(child: _buildEmptyState()),
        ],
      );
    }

    final grouped = _groupByDate(employeeRows);
    final dates = grouped.keys.toList();

    return Column(
      children: [
        _buildEmployeeSummary(user, present, late, absent),
        Expanded(
          child: ListView.builder(
            itemCount: dates.length,
            itemBuilder: (context, index) {
              final date = dates[index];
              final dayRows = grouped[date]!;

              DateTime? parsedDate = DateTime.tryParse(date);
              String headerText = date;
              if (parsedDate != null) {
                headerText =
                    DateFormat('EEEE, MMMM d').format(parsedDate).toUpperCase();
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          headerText,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: Colors.grey,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Divider(color: Colors.grey.withValues(alpha: 0.3)),
                      ],
                    ),
                  ),
                  ...dayRows
                      .map((row) => _buildCompactRow(row, showEmployee: false)),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEmployeeSummary(
    _HistoryUser user,
    int present,
    int late,
    int absent,
  ) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor:
                    Theme.of(context).primaryColor.withValues(alpha: 0.1),
                child: Text(
                  user.displayName.isNotEmpty
                      ? user.displayName.substring(0, 1).toUpperCase()
                      : '?',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.displayName,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'ID: ${user.uid.substring(0, 8)}...',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildSummaryStat('Present', present, Colors.green),
              _buildSummaryStat('Late', late, Colors.orange),
              _buildSummaryStat('Absent', absent, Colors.red),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryStat(String label, int value, Color color) {
    return Column(
      children: [
        Text(
          '$value',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade700,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search_off, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          const Text(
            'No attendance records found',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Try changing the date range or filters.',
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Map<String, List<_HistoryRow>> _groupByDate(List<_HistoryRow> rows) {
    final grouped = <String, List<_HistoryRow>>{};
    for (final row in rows) {
      if (!grouped.containsKey(row.date)) {
        grouped[row.date] = [];
      }
      grouped[row.date]!.add(row);
    }
    final keys = grouped.keys.toList()..sort((a, b) => b.compareTo(a));
    final sortedGrouped = <String, List<_HistoryRow>>{};
    for (final key in keys) {
      sortedGrouped[key] = grouped[key]!;
    }
    return sortedGrouped;
  }

  Widget _buildCompactRow(_HistoryRow row, {bool showEmployee = true}) {
    final isAbsent = row.status == 'absent';
    final isLate = row.status == 'late';
    final color =
        isAbsent ? Colors.red : (isLate ? Colors.orange : Colors.green);

    final avatarText = row.employeeName.isNotEmpty
        ? row.employeeName.substring(0, 1).toUpperCase()
        : '?';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.05),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            if (showEmployee) ...[
              CircleAvatar(
                radius: 20,
                backgroundColor: color.withValues(alpha: 0.15),
                child: Text(
                  avatarText,
                  style: TextStyle(color: color, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 16),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (showEmployee)
                    Text(
                      row.employeeName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  if (!showEmployee)
                    Text(
                      row.date,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      if (isAbsent)
                        Text(
                          'No attendance record',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 13,
                          ),
                        )
                      else ...[
                        Icon(
                          Icons.login,
                          size: 14,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          row.attendanceTime,
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Icon(
                          Icons.logout,
                          size: 14,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          row.checkoutTime,
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isAbsent
                        ? Icons.cancel
                        : (isLate
                            ? Icons.access_time_filled
                            : Icons.verified_user),
                    size: 14,
                    color: color,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    row.status.toUpperCase(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: color,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<_HistoryUser> _visibleUsers(
    List<_HistoryUser> users,
    UserModel currentUser,
    User authUser,
  ) {
    if (currentUser.isAdmin) {
      return users.where((user) => !user.isAdmin && !user.isManager).toList();
    }
    if (currentUser.isManager) {
      return users
          .where(
            (user) =>
                !user.isManager &&
                (user.createdBy == authUser.uid ||
                    user.managerId == authUser.uid ||
                    user.reportsTo == authUser.uid),
          )
          .toList();
    }
    return users.where((user) => user.uid == authUser.uid).toList();
  }

  _DateRange _selectedRange() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
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
    if (start.isAfter(today)) start = today;
    if (end.isAfter(today)) end = today;
    if (end.isBefore(start)) end = start;
    return _DateRange(
      start,
      end,
      '${DateFormat.yMMMd().format(start)} - ${DateFormat.yMMMd().format(end)}',
      _periodFilter,
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
      final employeeId =
          record['employeeId'] as String? ?? record['userId'] as String? ?? '';
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
      final date = DateFormat('yyyy-MM-dd').format(day);

      for (final user in users) {
        final record = byUserDate['${user.uid}|$date'];

        // For days_20_10: no day is ever "day off" — any day can be a working
        // day in the rotating 20-on/10-off cycle. Only standard schedules
        // treat weekends as non-working.
        bool expectedToWork = true;
        if (user.scheduleType != 'days_20_10' &&
            (day.weekday == DateTime.saturday ||
                day.weekday == DateTime.sunday)) {
          expectedToWork = false;
        }

        rows.add(_HistoryRow.from(user, date, record, expectedToWork));
      }
    }
    rows.sort(
      (a, b) => '${b.date} ${b.attendanceTime}'
          .compareTo('${a.date} ${a.attendanceTime}'),
    );
    return rows;
  }

  List<_HistoryRow> _filterRows(List<_HistoryRow> rows, String searchQuery) {
    var filtered = rows;
    final q = searchQuery.trim().toLowerCase();
    if (q.isNotEmpty) {
      filtered = filtered.where((row) => row.searchText.contains(q)).toList();
    }
    if (_statusFilter != 'All') {
      filtered = filtered
          .where((row) => row.status == _statusFilter.toLowerCase())
          .toList();
    }
    if (_selectedEmployeeId != null && _viewMode != _ViewMode.employee) {
      filtered = filtered
          .where((row) => row.employeeId == _selectedEmployeeId)
          .toList();
    }
    return filtered;
  }

  _HistoryStats _stats(
    List<_HistoryRow> rows,
    List<_HistoryUser> visibleUsers,
    _DateRange range,
  ) {
    var expected = 0;
    for (final user in visibleUsers) {
      expected += _workingDays(range, user.scheduleType);
    }

    final presentRecords = rows.where((row) => row.status == 'present').length;
    final lateRecords = rows.where((row) => row.status == 'late').length;
    final attendanceRecords = presentRecords + lateRecords;

    return _HistoryStats(
      workingDays: expected,
      absentDays: (expected - attendanceRecords).clamp(0, expected).toInt(),
      attendanceRecords: attendanceRecords,
      presentDays: presentRecords + lateRecords,
      lateDays: lateRecords,
    );
  }

  Iterable<DateTime> _days(_DateRange range) sync* {
    for (var day = range.start;
        !day.isAfter(range.end);
        day = day.add(const Duration(days: 1))) {
      yield day;
    }
  }

  int _workingDays(_DateRange range, [String scheduleType = 'standard']) {
    if (scheduleType == 'days_20_10') {
      if (range.period == _PeriodFilter.month) {
        return 20;
      }
      // For non-month ranges (week/year/custom), every calendar day can be
      // a work day in the rotating cycle — no weekends are automatically "off".
      return _days(range).length;
    }
    return _days(range)
        .where(
          (day) =>
              day.weekday != DateTime.saturday &&
              day.weekday != DateTime.sunday,
        )
        .length;
  }

  bool _inRange(DateTime day, _DateRange range) =>
      !day.isBefore(range.start) && !day.isAfter(range.end);
}

class _PersistentSearchBar extends StatefulWidget {
  const _PersistentSearchBar({
    super.key,
    required this.onChanged,
    required this.onClear,
  });

  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  State<_PersistentSearchBar> createState() => _PersistentSearchBarState();
}

class _PersistentSearchBarState extends State<_PersistentSearchBar> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleClear() {
    _controller.clear();
    widget.onClear();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        return SearchBar(
          controller: _controller,
          hintText: 'Search by employee, date, device, or status...',
          leading: const Icon(Icons.search),
          elevation: WidgetStateProperty.all(0),
          backgroundColor: WidgetStateProperty.all(
            Theme.of(context).dividerColor.withValues(alpha: 0.05),
          ),
          trailing: _controller.text.isNotEmpty
              ? [
                  IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: _handleClear,
                  ),
                ]
              : null,
          onChanged: widget.onChanged,
        );
      },
    );
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
    required this.scheduleType,
  });
  final String uid,
      displayName,
      status,
      createdBy,
      managerId,
      reportsTo,
      role,
      scheduleType;
  bool get isAdmin => role.trim().toLowerCase() == 'admin';
  bool get isManager => role.trim().toLowerCase() == 'manager';
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
      scheduleType:
          field('scheduleType').isEmpty ? 'standard' : field('scheduleType'),
    );
  }

  factory _HistoryUser.fromUserModel(UserModel user) {
    return _HistoryUser(
      uid: user.uid,
      displayName: user.displayName,
      status: user.status,
      createdBy: user.createdBy ?? '',
      managerId: user.managerId ?? '',
      reportsTo: '',
      role: user.role,
      scheduleType: user.scheduleType,
    );
  }
}

class _HistoryRow {
  const _HistoryRow({
    required this.employeeId,
    required this.employeeName,
    required this.date,
    required this.attendanceTime,
    required this.checkoutTime,
    required this.status,
    required this.device,
    required this.battery,
  });
  final String employeeId,
      employeeName,
      date,
      attendanceTime,
      checkoutTime,
      status,
      device;
  final Object battery;

  factory _HistoryRow.from(
    _HistoryUser user,
    String date,
    Map<String, dynamic>? record, [
    bool expectedToWork = true,
  ]) {
    if (record == null) {
      return _HistoryRow(
        employeeId: user.uid,
        employeeName: user.displayName,
        date: date,
        attendanceTime: '-',
        checkoutTime: '-',
        status: expectedToWork ? 'absent' : 'day_off',
        device: '-',
        battery: '-',
      );
    }
    String time(Object? value) {
      final raw = value?.toString() ?? '';
      final parsed = DateTime.tryParse(raw);
      return parsed == null
          ? (raw.isEmpty ? '-' : raw)
          : DateFormat('HH:mm:ss').format(parsed);
    }

    return _HistoryRow(
      employeeId: user.uid,
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
  const _DateRange(this.start, this.end, this.label, this.period);
  final DateTime start, end;
  final String label;
  final _PeriodFilter period;
}

class _HistoryStats {
  const _HistoryStats({
    required this.workingDays,
    required this.absentDays,
    required this.attendanceRecords,
    required this.presentDays,
    required this.lateDays,
  });
  final int workingDays, absentDays, attendanceRecords, presentDays, lateDays;
}
