import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/services/app_translations.dart';
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

    if (currentUser?.isAdmin == true) {
      return Scaffold(
        appBar: AppBar(title: Text(ref.tr('attendanceHistory'))),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Administrators do not record personal attendance. Use Attendance Reports & Analytics to verify employee records.',
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

    final content = StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('attendance')
          .where('employeeId', isEqualTo: authUser.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error loading history: ${snapshot.error}'));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final records = snapshot.data?.docs
                .map((doc) => doc.data() as Map<String, dynamic>)
                .toList() ??
            [];
        records.sort((a, b) {
          final aDate = '${a['date'] ?? ''} ${a['time'] ?? ''}';
          final bDate = '${b['date'] ?? ''} ${b['time'] ?? ''}';
          return bDate.compareTo(aDate);
        });

        final monthRecords = records.where(_isInSelectedMonth).toList();
        final summary = _AttendanceSummary.fromRecords(
          selectedMonth: _selectedMonth,
          records: monthRecords,
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
              onSearchChanged: (value) => _searchQueryNotifier.value = value,
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
    if (raw.isEmpty) return '—';
    final parsed = DateTime.tryParse(raw);
    return parsed == null ? raw : DateFormat('HH:mm:ss').format(parsed);
  }
}

class _MonthFilterCard extends StatefulWidget {
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
  State<_MonthFilterCard> createState() => _MonthFilterCardState();
}

class _MonthFilterCardState extends State<_MonthFilterCard> {
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
                    tooltip: 'Previous month',
                    onPressed: widget.onPreviousMonth,
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Expanded(
                    child: Text(
                      DateFormat('MMMM yyyy').format(widget.selectedMonth),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Next month',
                    onPressed: widget.onNextMonth,
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _searchController,
                onChanged: widget.onSearchChanged,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  labelText: 'Search by date, month, or status',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
      );
}

class _SummaryDashboard extends StatelessWidget {
  const _SummaryDashboard({required this.summary});

  final _AttendanceSummary summary;

  @override
  Widget build(BuildContext context) => Card(
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
                    'Monthly attendance summary',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              LinearProgressIndicator(value: summary.attendanceRatio),
              const SizedBox(height: 8),
              Text('${summary.attendancePercentage}% attendance rate'),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _StatTile(
                    icon: Icons.calendar_month,
                    label: 'Working days',
                    value: '${summary.workingDays}',
                    color: Colors.blue,
                  ),
                  _StatTile(
                    icon: Icons.login,
                    label: 'Check-ins',
                    value: '${summary.checkIns}',
                    color: Colors.green,
                  ),
                  _StatTile(
                    icon: Icons.person_off,
                    label: 'Absences',
                    value: '${summary.absences}',
                    color: Colors.red,
                  ),
                  _StatTile(
                    icon: Icons.schedule,
                    label: 'Late arrivals',
                    value: '${summary.lateArrivals}',
                    color: Colors.orange,
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
        width: 150,
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
            Text(label),
          ],
        ),
      );
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.record});

  final Map<String, dynamic> record;

  @override
  Widget build(BuildContext context) {
    final status = (record['status'] as String? ?? 'present').toLowerCase();
    final isLate = status == 'late';
    final color = isLate ? Colors.orange : Colors.green;
    final time = _HistoryScreenState.formatTime(record['time']);
    final checkout = _HistoryScreenState.formatTime(record['checkoutTime']);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.15),
          child: Icon(
            isLate ? Icons.access_time_filled : Icons.check_circle_outline,
            color: color,
          ),
        ),
        title: Text(
          record['date']?.toString() ?? 'Date',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          'Attendance time: $time\nCheck-out time: $checkout\nDevice: ${record['deviceModel'] ?? 'Mobile Device'}',
        ),
        isThreeLine: true,
        trailing: Chip(
          label: Text(status.toUpperCase()),
          backgroundColor: color.withValues(alpha: 0.15),
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
  }) {
    final workingDays = _countWeekdays(selectedMonth);
    final checkIns = records.length;
    final lateArrivals = records
        .where((record) =>
            (record['status'] as String? ?? '').trim().toLowerCase() == 'late',)
        .length;

    return _AttendanceSummary(
      workingDays: workingDays,
      checkIns: checkIns,
      absences: (workingDays - checkIns).clamp(0, workingDays).toInt(),
      lateArrivals: lateArrivals,
    );
  }

  static int _countWeekdays(DateTime month) {
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