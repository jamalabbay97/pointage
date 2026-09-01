import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
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

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  final ValueNotifier<String> _searchQueryNotifier = ValueNotifier('');

  @override
  void dispose() {
    _searchQueryNotifier.dispose();
    super.dispose();
  }

  static bool get _isWide =>
      kIsWeb ||
      defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.linux;

  @override
  Widget build(BuildContext context) {
    final authUser = FirebaseAuth.instance.currentUser;
    final currentUser = ref.watch(currentUserModelProvider).valueOrNull;

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

    if (authUser == null) {
      return Scaffold(
        appBar: AppBar(title: Text(ref.tr('attendanceHistory'))),
        body: Center(child: Text(ref.tr('noHistoryFound'))),
      );
    }

    final content = FutureBuilder<List<Map<String, dynamic>>>(
      future: ref.watch(offlineSyncServiceProvider).getPendingRecords(),
      builder: (context, pendingSnap) {
        final pendingRecords = pendingSnap.data ?? [];

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('attendance')
              .where('employeeId', isEqualTo: authUser.uid)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError && pendingRecords.isEmpty) {
              return Center(
                child:
                    Text('${ref.tr('errorLoadingHistory')}: ${snapshot.error}'),
              );
            }

            final firestoreRecords = snapshot.data?.docs
                    .map((doc) => doc.data() as Map<String, dynamic>)
                    .toList() ??
                [];

            // Merge pending records, avoiding duplicates
            final Map<String, Map<String, dynamic>> mergedMap = {};
            for (final r in firestoreRecords) {
              final id = r['id'] ?? '${r['employeeId']}-${r['date']}';
              mergedMap[id] = Map<String, dynamic>.from(r);
            }

            for (final p in pendingRecords) {
              final id =
                  p['id'] ?? p['docId'] ?? '${p['employeeId']}-${p['date']}';
              if (!mergedMap.containsKey(id)) {
                final copy = Map<String, dynamic>.from(p);
                copy['isPendingSync'] = true;
                mergedMap[id] = copy;
              } else {
                if (p.containsKey('checkoutTime') &&
                    p['checkoutTime'] != null) {
                  mergedMap[id]!['checkoutTime'] = p['checkoutTime'];
                  mergedMap[id]!['isPendingSync'] = true;
                }
              }
            }

            final records = mergedMap.values.toList();
            records.sort((a, b) {
              final aDate = '${a['date'] ?? ''} ${a['time'] ?? ''}';
              final bDate = '${b['date'] ?? ''} ${b['time'] ?? ''}';
              return bDate.compareTo(aDate);
            });

            final monthRecords = records.where(_isInSelectedMonth).toList();
            final scheduleType = currentUser?.scheduleType ?? 'standard';
            final summary = _AttendanceSummary.fromRecords(
              selectedMonth: _selectedMonth,
              records: monthRecords,
              scheduleType: scheduleType,
            );

            return ListView(
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
                const SizedBox(height: 12),
                _SummaryDashboard(summary: summary),
                const SizedBox(height: 16),
                ValueListenableBuilder<String>(
                  valueListenable: _searchQueryNotifier,
                  builder: (context, searchQuery, _) {
                    final filteredRecords = monthRecords
                        .where((record) => _matchesSearch(record, searchQuery))
                        .toList();
                    if (filteredRecords.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 48),
                        child: Center(child: Text(ref.tr('noHistoryFound'))),
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
            );
          },
        );
      },
    );

    return Scaffold(
      appBar: AppBar(title: Text(ref.tr('attendanceHistory'))),
      body: _isWide
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
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                    tooltip: ref.tr('previousMonth'),
                    onPressed: widget.onPreviousMonth,
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Expanded(
                    child: Text(
                      DateFormat('MMMM yyyy', ref.watch(languageProvider).code)
                          .format(widget.selectedMonth),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                  IconButton(
                    tooltip: ref.tr('nextMonth'),
                    onPressed: widget.onNextMonth,
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _searchController,
                onChanged: widget.onSearchChanged,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  labelText: ref.tr('searchByDateStatus'),
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
      );
}

class _SummaryDashboard extends ConsumerWidget {
  const _SummaryDashboard({required this.summary});

  final _AttendanceSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.insights),
                  const SizedBox(width: 8),
                  Text(
                    ref.tr('monthlyAttendanceSummary'),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              LinearProgressIndicator(value: summary.attendanceRatio),
              const SizedBox(height: 8),
              Text(
                '${summary.attendancePercentage}${ref.tr('attendanceRateLabel')}',
              ),
              const SizedBox(height: 16),
              Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _StatTile(
                          icon: Icons.calendar_month,
                          label: ref.tr('workingDays'),
                          value: '${summary.workingDays}',
                          color: Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _StatTile(
                          icon: Icons.login,
                          label: ref.tr('checkIns'),
                          value: '${summary.checkIns}',
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _StatTile(
                          icon: Icons.person_off,
                          label: ref.tr('absences'),
                          value: '${summary.absences}',
                          color: Colors.red,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _StatTile(
                          icon: Icons.schedule,
                          label: ref.tr('lateArrivals'),
                          value: '${summary.lateArrivals}',
                          color: Colors.orange,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      );
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      );
}

class _HistoryCard extends ConsumerWidget {
  const _HistoryCard({required this.record});

  final Map<String, dynamic> record;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = (record['status'] as String? ?? 'present').toLowerCase();
    final isLate = status == 'late';
    final isAbsent = status == 'absent';

    final Color color;
    final IconData icon;
    if (isAbsent) {
      color = Colors.redAccent;
      icon = Icons.cancel_outlined;
    } else if (isLate) {
      color = Colors.orange;
      icon = Icons.access_time_filled;
    } else {
      color = Colors.green;
      icon = Icons.check_circle_outline;
    }

    final time = _HistoryScreenState.formatTime(record['time']);
    final checkout = _HistoryScreenState.formatTime(record['checkoutTime']);

    final String subtitleText;
    if (isAbsent) {
      subtitleText =
          '${ref.tr('status')}: ${ref.tr('absent')}\n${ref.tr('device')}: ${record['deviceModel'] ?? 'Google Sheets Entry'}';
    } else {
      subtitleText =
          '${ref.tr('attendanceTime')}: $time\n${ref.tr('checkOutTime')}: $checkout\n${ref.tr('device')}: ${record['deviceModel'] ?? 'Mobile Device'}';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.15),
          child: Icon(
            icon,
            color: color,
          ),
        ),
        title: Text(
          record['date']?.toString() ?? ref.tr('date'),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(subtitleText),
        isThreeLine: true,
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Chip(
              visualDensity: VisualDensity.compact,
              label: Text(
                ref.tr(status).toUpperCase(),
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
              backgroundColor: color.withValues(alpha: 0.15),
              side: BorderSide.none,
            ),
            if (record['isPendingSync'] == true) ...[
              const SizedBox(height: 2),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.amber.shade900,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.cloud_off, size: 10, color: Colors.white),
                    const SizedBox(width: 4),
                    Text(
                      ref.tr('pendingSyncLabel'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
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
