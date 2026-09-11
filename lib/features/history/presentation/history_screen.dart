import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/services/app_translations.dart';
import '../../../core/services/language_provider.dart';
import '../../attendance/domain/offline_sync_service.dart';
import '../../auth/domain/auth_provider.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

enum AttendanceFilterType {
  allAttended,
  presentOnly,
  lateOnly,
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  final ValueNotifier<String> _searchQueryNotifier = ValueNotifier('');
  AttendanceFilterType _attendanceFilter = AttendanceFilterType.allAttended;

  @override
  void dispose() {
    _searchQueryNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authUser = FirebaseAuth.instance.currentUser;
    final currentUserAsync = ref.watch(currentUserModelProvider);
    final currentUser = currentUserAsync.valueOrNull;
    final effectiveUid = authUser?.uid ?? currentUser?.uid;

    if (currentUser?.isAdmin == true || currentUser?.isManager == true) {
      return Scaffold(
        appBar: AppBar(title: Text(ref.tr('attendanceHistory'))),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              currentUser?.isAdmin == true
                  ? ref.tr('adminNoAttendance')
                  : ref.tr('managerNoAttendance'),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    if (effectiveUid == null) {
      if (currentUserAsync.isLoading) {
        return Scaffold(
          appBar: AppBar(title: Text(ref.tr('attendanceHistory'))),
          body: const Center(child: CircularProgressIndicator()),
        );
      }
      return Scaffold(
        appBar: AppBar(title: Text(ref.tr('attendanceHistory'))),
        body: Center(child: Text(ref.tr('notAuthenticated'))),
      );
    }

    final content = FutureBuilder<List<Map<String, dynamic>>>(
      future: ref.watch(offlineSyncServiceProvider).getPendingRecords(),
      builder: (context, pendingSnap) {
        final pendingRecords = pendingSnap.data ?? [];

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('attendance')
              .where('employeeId', isEqualTo: effectiveUid)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError && pendingRecords.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.cloud_off_rounded,
                          size: 40,
                          color: Color(0xFFEF4444),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '${ref.tr('errorLoadingHistory')}: ${snapshot.error}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 13),
                      ),
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        onPressed: () => setState(() {}),
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: Text(ref.tr('retry')),
                      ),
                    ],
                  ),
                ),
              );
            }

            final firestoreRecords = snapshot.data?.docs
                    .map((doc) => doc.data() as Map<String, dynamic>)
                    .toList() ??
                [];

            // Merge pending records, avoiding duplicates
            final Map<String, Map<String, dynamic>> mergedMap = {};
            for (final r in firestoreRecords) {
              final date = r['date']?.toString();
              if (date != null && date.isNotEmpty) {
                final key = '${r['employeeId'] ?? effectiveUid}-$date';
                mergedMap[key] = Map<String, dynamic>.from(r);
              }
            }

            for (final p in pendingRecords) {
              final date = p['date']?.toString();
              if (date != null && date.isNotEmpty) {
                final key = '${p['employeeId'] ?? effectiveUid}-$date';
                if (!mergedMap.containsKey(key)) {
                  final copy = Map<String, dynamic>.from(p);
                  copy['isPendingSync'] = true;
                  mergedMap[key] = copy;
                } else {
                  if (p.containsKey('checkoutTime') &&
                      p['checkoutTime'] != null) {
                    mergedMap[key]!['checkoutTime'] = p['checkoutTime'];
                    if (p.containsKey('checkoutLatitude')) {
                      mergedMap[key]!['checkoutLatitude'] =
                          p['checkoutLatitude'];
                    }
                    if (p.containsKey('checkoutLongitude')) {
                      mergedMap[key]!['checkoutLongitude'] =
                          p['checkoutLongitude'];
                    }
                    mergedMap[key]!['isPendingSync'] = true;
                  }
                }
              }
            }

            // Generate entries for all days that have passed in _selectedMonth
            final now = DateTime.now();
            final today = DateTime(now.year, now.month, now.day);
            final startOfMonth =
                DateTime(_selectedMonth.year, _selectedMonth.month, 1);
            final endOfMonth =
                DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0);

            final int lastPassedDay;
            if (startOfMonth.isAfter(today)) {
              lastPassedDay = 0;
            } else if (endOfMonth.isBefore(today)) {
              lastPassedDay = endOfMonth.day;
            } else {
              lastPassedDay = today.day;
            }

            final scheduleType = currentUser?.scheduleType ?? 'standard';
            final bool is2010 = scheduleType == 'days_20_10';

            for (int day = 1; day <= lastPassedDay; day++) {
              final date =
                  DateTime(_selectedMonth.year, _selectedMonth.month, day);
              final dateStr = DateFormat('yyyy-MM-dd').format(date);
              final key = '$effectiveUid-$dateStr';

              if (!mergedMap.containsKey(key)) {
                final bool isWeekend = date.weekday == DateTime.saturday ||
                    date.weekday == DateTime.sunday;
                final String status =
                    (is2010 || !isWeekend) ? 'absent' : 'day_off';

                mergedMap[key] = {
                  'employeeId': effectiveUid,
                  'employeeName': currentUser?.displayName ?? '',
                  'date': dateStr,
                  'time': null,
                  'checkoutTime': null,
                  'status': status,
                  'scheduleType': scheduleType,
                };
              }
            }

            final records = mergedMap.values.toList();
            records.sort((a, b) {
              final aDate = '${a['date'] ?? ''} ${a['time'] ?? ''}';
              final bDate = '${b['date'] ?? ''} ${b['time'] ?? ''}';
              return bDate.compareTo(aDate);
            });

            final monthRecords = records.where(_isInSelectedMonth).toList();
            final summary = _AttendanceSummary.fromRecords(
              selectedMonth: _selectedMonth,
              records: monthRecords,
              scheduleType: scheduleType,
            );

            // Filter out absent and day-off records: display only attendance days and late days
            final attendedRecords = monthRecords.where((r) {
              final status =
                  (r['status'] as String? ?? '').trim().toLowerCase();
              final isLate = status == 'late';
              final isPresent = status != 'absent' &&
                  status != 'day_off' &&
                  status != 'dayoff' &&
                  status != 'off' &&
                  status != 'leave' &&
                  status != 'holiday' &&
                  !isLate;

              switch (_attendanceFilter) {
                case AttendanceFilterType.allAttended:
                  return isPresent || isLate;
                case AttendanceFilterType.presentOnly:
                  return isPresent;
                case AttendanceFilterType.lateOnly:
                  return isLate;
              }
            }).toList();

            return Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _MonthFilterCard(
                        key: const ValueKey('history-month-filter'),
                        selectedMonth: _selectedMonth,
                        onPreviousMonth: () => setState(
                          () => _selectedMonth = DateTime(
                            _selectedMonth.year,
                            _selectedMonth.month - 1,
                          ),
                        ),
                        onNextMonth: () => setState(
                          () => _selectedMonth = DateTime(
                            _selectedMonth.year,
                            _selectedMonth.month + 1,
                          ),
                        ),
                        onSearchChanged: (value) =>
                            _searchQueryNotifier.value = value,
                      ),
                      const SizedBox(height: 14),
                      ValueListenableBuilder<String>(
                        valueListenable: _searchQueryNotifier,
                        builder: (context, searchQuery, _) {
                          final filteredRecords = attendedRecords
                              .where(
                                (record) => _matchesSearch(record, searchQuery),
                              )
                              .toList();
                          if (filteredRecords.isEmpty) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 48),
                              child: Center(
                                child: Text(
                                  ref.tr('noHistoryFound'),
                                  style: TextStyle(
                                    color: Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? const Color(0xFF94A3B8)
                                        : const Color(0xFF64748B),
                                  ),
                                ),
                              ),
                            );
                          }
                          return Column(
                            children: filteredRecords
                                .map((record) => _HistoryCard(record: record))
                                .toList(),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                _AttendanceBottomBar(
                  summary: summary,
                  activeFilter: _attendanceFilter,
                  onFilterChanged: (filter) =>
                      setState(() => _attendanceFilter = filter),
                ),
              ],
            );
          },
        );
      },
    );

    final isWide = MediaQuery.sizeOf(context).width >= 820;

    return Scaffold(
      appBar: AppBar(title: Text(ref.tr('attendanceHistory'))),
      body: isWide
          ? Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 820),
                child: content,
              ),
            )
          : content,
    );
  }

  bool _isInSelectedMonth(Map<String, dynamic> record) {
    final date = _recordDate(record);
    return date != null &&
        date.year == _selectedMonth.year &&
        date.month == _selectedMonth.month;
  }

  bool _matchesSearch(Map<String, dynamic> record, String searchQuery) {
    final query = searchQuery.trim().toLowerCase();
    if (query.isEmpty) return true;
    final status = (record['status'] ?? '').toString().toLowerCase();
    final date = (record['date'] ?? '').toString().toLowerCase();
    final month = DateFormat('MMMM yyyy').format(_selectedMonth).toLowerCase();
    return date.contains(query) ||
        status.contains(query) ||
        month.contains(query);
  }

  static DateTime? _recordDate(Map<String, dynamic> record) {
    final date = record['date']?.toString();
    return date == null ? null : DateTime.tryParse(date);
  }

  static String formatTime(Object? value) {
    final raw = value?.toString() ?? '';
    if (raw.isEmpty) return '-';
    final parsed = DateTime.tryParse(raw);
    return parsed == null ? raw : DateFormat('HH:mm:ss').format(parsed);
  }
}

class _MonthFilterCard extends ConsumerStatefulWidget {
  const _MonthFilterCard({
    super.key,
    required this.selectedMonth,
    required this.onPreviousMonth,
    required this.onNextMonth,
    required this.onSearchChanged,
  });

  final DateTime selectedMonth;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;
  final ValueChanged<String> onSearchChanged;

  @override
  ConsumerState<_MonthFilterCard> createState() => _MonthFilterCardState();
}

class _MonthFilterCardState extends ConsumerState<_MonthFilterCard> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131B2E) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? const Color.fromRGBO(0, 0, 0, 0.3)
                : const Color.fromRGBO(15, 23, 42, 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton.filledTonal(
                tooltip: ref.tr('previousMonth'),
                onPressed: widget.onPreviousMonth,
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              Expanded(
                child: Text(
                  DateFormat('MMMM yyyy', ref.watch(languageProvider).code)
                      .format(widget.selectedMonth),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
              IconButton.filledTonal(
                tooltip: ref.tr('nextMonth'),
                onPressed: widget.onNextMonth,
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _searchController,
            onChanged: widget.onSearchChanged,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        widget.onSearchChanged('');
                      },
                    )
                  : null,
              hintText: ref.tr('searchByDateStatus'),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _AttendanceBottomBar extends ConsumerWidget {
  const _AttendanceBottomBar({
    required this.summary,
    required this.activeFilter,
    required this.onFilterChanged,
  });

  final _AttendanceSummary summary;
  final AttendanceFilterType activeFilter;
  final ValueChanged<AttendanceFilterType> onFilterChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final onTimeCount =
        (summary.checkIns - summary.lateArrivals).clamp(0, summary.checkIns);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
            width: 1.2,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? const Color.fromRGBO(0, 0, 0, 0.4)
                : const Color.fromRGBO(15, 23, 42, 0.08),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Summary Info Row (Working Days, Absences, Attendance %)
              Row(
                children: [
                  _SummaryChip(
                    icon: Icons.calendar_month_rounded,
                    label: '${summary.workingDays} ${ref.tr('workingDays')}',
                    color: const Color(0xFF3B82F6),
                  ),
                  const SizedBox(width: 8),
                  _SummaryChip(
                    icon: Icons.person_off_rounded,
                    label: '${summary.absences} ${ref.tr('absences')}',
                    color: const Color(0xFFEF4444),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2.5,
                    ),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF4F46E5), Color(0xFF6366F1)],
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${summary.attendancePercentage}%',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Interactive Filter Selector Row
              Row(
                children: [
                  Expanded(
                    child: _FilterButton(
                      label: ref.tr('present'),
                      count: onTimeCount,
                      icon: Icons.check_circle_rounded,
                      color: const Color(0xFF10B981),
                      isSelected:
                          activeFilter == AttendanceFilterType.presentOnly,
                      onTap: () => onFilterChanged(
                        activeFilter == AttendanceFilterType.presentOnly
                            ? AttendanceFilterType.allAttended
                            : AttendanceFilterType.presentOnly,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _FilterButton(
                      label: ref.tr('late'),
                      count: summary.lateArrivals,
                      icon: Icons.access_time_filled_rounded,
                      color: const Color(0xFFF59E0B),
                      isSelected: activeFilter == AttendanceFilterType.lateOnly,
                      onTap: () => onFilterChanged(
                        activeFilter == AttendanceFilterType.lateOnly
                            ? AttendanceFilterType.allAttended
                            : AttendanceFilterType.lateOnly,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _AllAttendedButton(
                    count: summary.checkIns,
                    isSelected:
                        activeFilter == AttendanceFilterType.allAttended,
                    onTap: () =>
                        onFilterChanged(AttendanceFilterType.allAttended),
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

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.18 : 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterButton extends StatelessWidget {
  const _FilterButton({
    required this.label,
    required this.count,
    required this.icon,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final int count;
  final IconData icon;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: isSelected
          ? color.withValues(alpha: isDark ? 0.22 : 0.15)
          : (isDark ? const Color(0xFF131B2E) : const Color(0xFFF1F5F9)),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? color : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                    color: isSelected
                        ? color
                        : (isDark
                            ? const Color(0xFFE2E8F0)
                            : const Color(0xFF334155)),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                decoration: BoxDecoration(
                  color: isSelected ? color : color.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.white : color,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AllAttendedButton extends StatelessWidget {
  const _AllAttendedButton({
    required this.count,
    required this.isSelected,
    required this.onTap,
  });

  final int count;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const color = Color(0xFF6366F1);

    return Material(
      color: isSelected
          ? color.withValues(alpha: isDark ? 0.22 : 0.15)
          : (isDark ? const Color(0xFF131B2E) : const Color(0xFFF1F5F9)),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? color : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.done_all_rounded, size: 16, color: color),
              const SizedBox(width: 4),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                decoration: BoxDecoration(
                  color: isSelected ? color : color.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.white : color,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HistoryCard extends ConsumerWidget {
  const _HistoryCard({required this.record});

  final Map<String, dynamic> record;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final status = (record['status'] as String? ?? 'present').toLowerCase();
    final isLate = status == 'late';
    final isAbsent = status == 'absent';
    final isDayOff =
        status == 'day_off' || status == 'dayoff' || status == 'off';

    final Color statusColor;
    final IconData statusIcon;
    if (isAbsent) {
      statusColor = const Color(0xFFEF4444);
      statusIcon = Icons.cancel_rounded;
    } else if (isLate) {
      statusColor = const Color(0xFFF59E0B);
      statusIcon = Icons.access_time_filled_rounded;
    } else if (isDayOff) {
      statusColor = const Color(0xFF64748B);
      statusIcon = Icons.event_busy_rounded;
    } else {
      statusColor = const Color(0xFF10B981);
      statusIcon = Icons.check_circle_rounded;
    }

    final time = _HistoryScreenState.formatTime(record['time']);
    final checkout = _HistoryScreenState.formatTime(record['checkoutTime']);
    final isPending = record['isPendingSync'] == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131B2E) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? const Color.fromRGBO(0, 0, 0, 0.3)
                : const Color.fromRGBO(15, 23, 42, 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            // Top Row: Date + Status Badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(
                          alpha: isDark ? 0.2 : 0.12,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(statusIcon, color: statusColor, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      record['date']?.toString() ?? ref.tr('date'),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    if (isPending) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        margin: const EdgeInsets.only(right: 6),
                        decoration: BoxDecoration(
                          color:
                              const Color(0xFFF59E0B).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color:
                                const Color(0xFFF59E0B).withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.cloud_off_rounded,
                              size: 11,
                              color: Color(0xFFF59E0B),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              ref.tr('pendingSyncLabel'),
                              style: const TextStyle(
                                color: Color(0xFFF59E0B),
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(
                          alpha: isDark ? 0.2 : 0.12,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: statusColor.withValues(
                            alpha: isDark ? 0.35 : 0.25,
                          ),
                        ),
                      ),
                      child: Text(
                        ref.trStatus(status).toUpperCase(),
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 14),
            // Dual Punch Times Row
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF0F172A)
                          : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.login_rounded,
                          size: 16,
                          color: Color(0xFF10B981),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              ref.tr('attendanceTime'),
                              style: TextStyle(
                                fontSize: 10,
                                color: isDark
                                    ? const Color(0xFF94A3B8)
                                    : const Color(0xFF64748B),
                              ),
                            ),
                            Text(
                              time,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF0F172A)
                          : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.logout_rounded,
                          size: 16,
                          color: Color(0xFF3B82F6),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              ref.tr('checkOutTime'),
                              style: TextStyle(
                                fontSize: 10,
                                color: isDark
                                    ? const Color(0xFF94A3B8)
                                    : const Color(0xFF64748B),
                              ),
                            ),
                            Text(
                              checkout,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AttendanceSummary {
  const _AttendanceSummary({
    required this.workingDays,
    required this.checkIns,
    required this.absences,
    required this.lateArrivals,
  });

  final int workingDays;
  final int checkIns;
  final int absences;
  final int lateArrivals;

  double get attendanceRatio =>
      workingDays == 0 ? 0 : (checkIns / workingDays).clamp(0, 1).toDouble();

  int get attendancePercentage => (attendanceRatio * 100).round();

  factory _AttendanceSummary.fromRecords({
    required DateTime selectedMonth,
    required List<Map<String, dynamic>> records,
    String scheduleType = 'standard',
  }) {
    final workingDays = _countWorkingDays(selectedMonth, scheduleType);
    final presentRecords = records.where((r) {
      final s = (r['status'] as String? ?? 'present').trim().toLowerCase();
      return s != 'absent' && s != 'day_off' && s != 'leave' && s != 'holiday';
    }).toList();

    final checkIns = presentRecords.length;
    final lateArrivals = records
        .where(
          (record) =>
              (record['status'] as String? ?? '').trim().toLowerCase() ==
              'late',
        )
        .length;

    return _AttendanceSummary(
      workingDays: workingDays,
      checkIns: checkIns,
      absences: (workingDays - checkIns).clamp(0, workingDays).toInt(),
      lateArrivals: lateArrivals,
    );
  }

  /// Calculates the number of working days in [month] based on [scheduleType].
  ///
  /// - `'days_20_10'`: Fixed 20 working days per month (rotating 20-on/10-off).
  /// - `'standard'` (or any other value): Count weekdays (Monday–Friday).
  static int _countWorkingDays(DateTime month, String scheduleType) {
    if (scheduleType == 'days_20_10') return 20;
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    var weekdays = 0;
    for (var day = 1; day <= daysInMonth; day++) {
      final date = DateTime(month.year, month.month, day);
      if (date.weekday != DateTime.saturday &&
          date.weekday != DateTime.sunday) {
        weekdays++;
      }
    }
    return weekdays;
  }
}
