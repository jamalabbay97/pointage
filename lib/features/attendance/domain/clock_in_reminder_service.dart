import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/services/app_translations.dart';
import '../../../core/services/local_notification_service.dart';
import '../../auth/domain/auth_provider.dart';
import '../../notifications/data/notification_provider.dart';
import '../../settings/data/settings_provider.dart';
import 'offline_sync_service.dart';

class ClockInReminderService {
  const ClockInReminderService(this._ref);

  final Ref _ref;

  /// Checks if the employee has not clocked in today and dispatches both in-app
  /// and external device notifications reminding them to clock in.
  Future<void> checkAndNotifyIfNeeded({
    required User user,
    BuildContext? context,
    required bool isNotCheckedIn,
  }) async {
    if (!isNotCheckedIn) return;

    final currentUser = _ref.read(currentUserModelProvider).valueOrNull;
    // Strict restriction: ONLY workers/employees who are required to record attendance
    if (currentUser == null ||
        !currentUser.isEmployee ||
        currentUser.isAdmin ||
        currentUser.isManager) {
      return;
    }

    final userSettings = _ref.read(userSettingsProvider).valueOrNull;
    final remindersEnabled = userSettings?.dailyReminders ?? true;
    if (!remindersEnabled) return;

    final now = DateTime.now();
    // Do not remind on scheduled days off (e.g. weekends for standard schedule)
    final schedule = currentUser.scheduleType;
    if (schedule == 'standard' &&
        (now.weekday == DateTime.saturday || now.weekday == DateTime.sunday)) {
      return;
    }

    final today = now.toIso8601String().substring(0, 10);

    // Determine reminder type based on current time:
    // Before or at shift start time (08:15 AM) -> "Attendance Required"
    // Past shift start time (after 08:15 AM) -> "You Forgot to Check In"
    final isPastShiftStart = now.hour > 8 || (now.hour == 8 && now.minute > 15);

    final String titleKey;
    final String bodyKey;
    final String dedupKey;

    if (isPastShiftStart) {
      titleKey = 'forgotClockInTitle';
      bodyKey = 'forgotClockInBody';
      dedupKey = 'forgot_clock_in_reminder_sent_${user.uid}_$today';
    } else {
      titleKey = 'attendanceRequired';
      bodyKey = 'attendanceRequiredBody';
      dedupKey = 'attendance_required_sent_${user.uid}_$today';
    }

    final prefs = await SharedPreferences.getInstance();
    final alreadySent = prefs.getBool(dedupKey) ?? false;
    if (alreadySent) return;

    // Check local pending records first (offline clock-in)
    try {
      final pending =
          await _ref.read(offlineSyncServiceProvider).getPendingRecords();
      final hasLocalToday =
          pending.any((r) => r['employeeId'] == user.uid && r['date'] == today);
      if (hasLocalToday) return;
    } catch (_) {}

    // Check Firestore double-check to confirm attendance status for today
    try {
      final docId = '${user.uid}-$today';
      final docSnap = await FirebaseFirestore.instance
          .collection('attendance')
          .doc(docId)
          .get()
          .timeout(const Duration(seconds: 2));

      if (docSnap.exists) {
        final data = docSnap.data();
        final status = (data?['status'] as String? ?? '').toLowerCase();
        if (status != 'absent' && status.isNotEmpty) {
          // Employee has actually clocked in
          return;
        }
      }
    } catch (_) {
      // Proceed if network check fails
    }

    final title = _ref.tr(titleKey);
    final body = _ref.tr(bodyKey);

    // 1. Send In-App Notification (Firestore)
    try {
      final notificationService = _ref.read(notificationServiceProvider);
      await notificationService.send(
        title: title,
        body: body,
        type: 'reminder',
        titleKey: titleKey,
        bodyKey: bodyKey,
        senderId: user.uid,
        senderName: 'System',
        targetUserId: user.uid,
      );
    } catch (e) {
      debugPrint('Failed to store in-app reminder notification: $e');
    }

    // 2. Trigger External System/Device Notification
    try {
      final localNotif = LocalNotificationService();
      final notifId = (user.uid + today + titleKey).hashCode;
      await localNotif.showNotification(
        id: notifId.abs(),
        title: title,
        body: body,
      );
    } catch (e) {
      debugPrint('Failed to display external local notification: $e');
    }

    // Mark reminder as sent for today
    await prefs.setBool(dedupKey, true);
  }
}

final clockInReminderServiceProvider = Provider<ClockInReminderService>((ref) {
  return ClockInReminderService(ref);
});
