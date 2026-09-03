import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/services/app_translations.dart';
import '../../../core/services/local_notification_service.dart';
import '../../notifications/data/notification_provider.dart';
import '../../settings/data/settings_provider.dart';

class ClockInReminderService {
  const ClockInReminderService(this._ref);

  final Ref _ref;

  /// Checks if the employee has not clocked in today and dispatches both in-app
  /// and external device notifications reminding them to clock in.
  Future<void> checkAndNotifyIfNeeded({
    required User user,
    required BuildContext context,
    required bool isNotCheckedIn,
  }) async {
    if (!isNotCheckedIn) return;

    final userSettings = _ref.read(userSettingsProvider).valueOrNull;
    final remindersEnabled = userSettings?.dailyReminders ?? true;
    if (!remindersEnabled) return;

    final now = DateTime.now();
    final today = now.toIso8601String().substring(0, 10);

    final prefs = await SharedPreferences.getInstance();
    final key = 'forgot_clock_in_reminder_sent_${user.uid}_$today';
    final alreadySent = prefs.getBool(key) ?? false;

    if (alreadySent) return;

    // Check Firestore double-check to confirm attendance status for today
    try {
      final docId = '${user.uid}-$today';
      final docSnap = await FirebaseFirestore.instance
          .collection('attendance')
          .doc(docId)
          .get();

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

    final title = _ref.tr('forgotClockInTitle');
    final body = _ref.tr('forgotClockInBody');

    // 1. Send In-App Notification (Firestore)
    try {
      final notificationService = _ref.read(notificationServiceProvider);
      await notificationService.send(
        title: title,
        body: body,
        type: 'reminder',
        senderId: 'system',
        senderName: 'System',
        targetUserId: user.uid,
      );
    } catch (e) {
      debugPrint('Failed to store in-app reminder notification: $e');
    }

    // 2. Trigger External System/Device Notification
    try {
      final localNotif = LocalNotificationService();
      final notifId = (user.uid + today).hashCode;
      await localNotif.showNotification(
        id: notifId.abs(),
        title: title,
        body: body,
      );
    } catch (e) {
      debugPrint('Failed to display external local notification: $e');
    }

    // Mark reminder as sent for today
    await prefs.setBool(key, true);
  }
}

final clockInReminderServiceProvider = Provider<ClockInReminderService>((ref) {
  return ClockInReminderService(ref);
});
