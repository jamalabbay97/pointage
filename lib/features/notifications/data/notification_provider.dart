import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/notification_model.dart';
import '../../../core/models/user_model.dart';
import '../../auth/domain/auth_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Service
// ─────────────────────────────────────────────────────────────────────────────

class NotificationService {
  const NotificationService(this._db);
  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('notifications');

  /// Sends a notification.
  /// Admin → type='admin', senderName=null, targetManagerId=null.
  /// Manager → type='manager', senderName=manager's displayName,
  ///           targetManagerId=manager's UID.
  Future<void> send({
    required String title,
    required String body,
    required String type,
    required String senderId,
    String? titleKey,
    String? bodyKey,
    String? senderName,
    String? targetManagerId,
    String? targetUserId,
    String? link,
  }) async {
    await _col.add({
      'title': title,
      'body': body,
      'type': type,
      'senderId': senderId,
      if (titleKey != null) 'titleKey': titleKey,
      if (bodyKey != null) 'bodyKey': bodyKey,
      if (senderName != null) 'senderName': senderName,
      if (targetManagerId != null) 'targetManagerId': targetManagerId,
      if (targetUserId != null) 'targetUserId': targetUserId,
      if (link != null) 'link': link,
      'createdAt': FieldValue.serverTimestamp(),
      'readBy': <String>[],
      'deletedBy': <String>[],
    });
  }

  /// Appends the current user's UID to a notification's [readBy] list.
  Future<void> markAsRead(String docId, String uid) async {
    await _col.doc(docId).update({
      'readBy': FieldValue.arrayUnion([uid]),
    });
  }

  /// Appends the current user's UID to a notification's [deletedBy] list.
  Future<void> markAsDeleted(String docId, String uid) async {
    await _col.doc(docId).update({
      'deletedBy': FieldValue.arrayUnion([uid]),
    });
  }

  /// Deletes the notification document globally (Admin only).
  Future<void> deleteGlobally(String docId) async {
    await _col.doc(docId).delete();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Providers
// ─────────────────────────────────────────────────────────────────────────────

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService(FirebaseFirestore.instance);
});

/// Stream of notifications visible to the current user.
///
/// Visibility rules:
/// - Admin notifications (`type == 'admin'`): visible to everyone.
/// - Manager notifications (`type == 'manager'`): visible only to employees
///   whose `managerId` matches the notification's `targetManagerId`.
final userNotificationsProvider = StreamProvider<List<AppNotification>>((ref) {
  final authUser = ref.watch(authStateProvider).valueOrNull;
  final userModel = ref.watch(currentUserModelProvider).valueOrNull;

  if (authUser == null) return Stream.value([]);

  return FirebaseFirestore.instance
      .collection('notifications')
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((snap) {
    return snap.docs
        .map((d) => AppNotification.fromJson(d.data(), d.id))
        .where((n) => _isVisible(n, authUser, userModel))
        .toList();
  });
});

bool _isVisible(
  AppNotification n,
  User authUser,
  UserModel? userModel,
) {
  // If the user has deleted this notification, don't show it
  if (n.deletedBy.contains(authUser.uid)) {
    return false;
  }

  // If the notification was sent before the user account was created, don't show it
  if (userModel?.createdAt != null &&
      n.createdAt.isBefore(userModel!.createdAt!)) {
    return false;
  }

  // Check if notification is an attendance requirement / check-in reminder
  final isAttendanceReminder = n.isReminderType ||
      n.titleKey == 'attendanceRequired' ||
      n.titleKey == 'forgotClockInTitle' ||
      n.title.toLowerCase().contains('attendance required') ||
      n.title.toLowerCase().contains('forgot') ||
      n.title.toLowerCase().contains('clock-in') ||
      n.title.toLowerCase().contains('présence requise') ||
      n.title.toLowerCase().contains('oublié') ||
      n.title.toLowerCase().contains('تسجيل الحضور مطلوب') ||
      n.title.toLowerCase().contains('نسيت') ||
      n.title.toLowerCase().contains('asistencia requerida') ||
      n.title.toLowerCase().contains('olvidaste');

  // Rule: Admin and Manager accounts MUST NEVER receive or display attendance reminders
  if (userModel?.isAdmin == true || userModel?.isManager == true) {
    if (isAttendanceReminder) return false;
    return n.isAdminType || n.senderId == authUser.uid;
  }

  // Attendance reminders are strictly displayed for employees/workers required to record attendance
  if (isAttendanceReminder) {
    if (userModel?.isEmployee != true) return false;
    if (n.targetUserId != null) {
      return n.targetUserId == authUser.uid;
    }
    return true;
  }

  // Notifications targeted to specific user
  if (n.targetUserId != null) {
    return n.targetUserId == authUser.uid;
  }

  // Admin broadcasts → all users
  if (n.isAdminType) return true;
  // Manager notifications → only employees registered by that manager
  if (n.isManagerType) {
    final mid = n.targetManagerId;
    if (mid == null) return false;
    return userModel?.managerId == mid;
  }
  return false;
}

/// Number of notifications the current user has NOT yet read.
final unreadNotificationCountProvider = Provider<int>((ref) {
  final authUser = ref.watch(authStateProvider).valueOrNull;
  final notifications = ref.watch(userNotificationsProvider).valueOrNull ?? [];
  if (authUser == null) return 0;
  return notifications.where((n) => !n.readBy.contains(authUser.uid)).length;
});
