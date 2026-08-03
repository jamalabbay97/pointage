import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/services/app_translations.dart';
import '../../auth/domain/auth_provider.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  static bool get _isWide =>
      kIsWeb ||
      defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.linux;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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

    final body = StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('attendance')
          .where('employeeId', isEqualTo: authUser.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text('Error loading history: ${snapshot.error}'),
          );
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

        if (records.isEmpty) {
          return Center(child: Text(ref.tr('noHistoryFound')));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: records.length,
          itemBuilder: (context, index) {
            final record = records[index];
            final status =
                (record['status'] as String? ?? 'present').toLowerCase();
            final isLate = status == 'late';
            final color = isLate ? Colors.orange : Colors.green;
            final time = _formatTime(record['time']);
            final checkout = _formatTime(record['checkoutTime']);
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: color.withValues(alpha: 0.15),
                  child: Icon(
                    isLate
                        ? Icons.access_time_filled
                        : Icons.check_circle_outline,
                    color: color,
                  ),
                ),
                title: Text(
                  record['date']?.toString() ?? ref.tr('date'),
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
                constraints: const BoxConstraints(maxWidth: 760),
                child: body,
              ),
            )
          : body,
    );
  }

  static String _formatTime(Object? value) {
    final raw = value?.toString() ?? '';
    if (raw.isEmpty) return '—';
    final parsed = DateTime.tryParse(raw);
    return parsed == null ? raw : DateFormat('HH:mm:ss').format(parsed);
  }
}
