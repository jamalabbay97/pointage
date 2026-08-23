import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/models/notification_model.dart';
import '../../../core/widgets/web_layout.dart';
import '../../auth/domain/auth_provider.dart';
import '../data/notification_provider.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(userNotificationsProvider);
    final authUser = ref.watch(authStateProvider).valueOrNull;
    final notificationService = ref.read(notificationServiceProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          notificationsAsync.when(
            data: (list) {
              final unread = authUser == null
                  ? 0
                  : list.where((n) => !n.readBy.contains(authUser.uid)).length;
              
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (unread > 0)
                    TextButton.icon(
                      onPressed: () async {
                        if (authUser == null) return;
                        for (final n in list) {
                          if (!n.readBy.contains(authUser.uid)) {
                            await notificationService.markAsRead(n.id, authUser.uid);
                          }
                        }
                      },
                      icon: const Icon(Icons.done_all_rounded, size: 18),
                      label: const Text('Mark all read'),
                    ),
                  if (list.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.delete_sweep_rounded),
                      tooltip: 'Clear all',
                      onPressed: () async {
                        if (authUser == null) return;
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (c) => AlertDialog(
                            title: const Text('Clear All Notifications?'),
                            content: const Text('Are you sure you want to delete all notifications? This action cannot be undone.'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(c, false),
                                child: const Text('Cancel'),
                              ),
                              FilledButton(
                                onPressed: () => Navigator.pop(c, true),
                                child: const Text('Clear All'),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          for (final n in list) {
                            await notificationService.markAsDeleted(n.id, authUser.uid);
                          }
                        }
                      },
                    ),
                ],
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
      body: WebLayout(
        child: notificationsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (notifications) {
            if (notifications.isEmpty) {
              return _EmptyState(isDark: isDark);
            }
            return ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              itemCount: notifications.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final n = notifications[index];
                final isRead =
                    authUser != null && n.readBy.contains(authUser.uid);
                return _NotificationCard(
                  notification: n,
                  isRead: isRead,
                  onTap: () {
                    if (!isRead && authUser != null) {
                      notificationService.markAsRead(n.id, authUser.uid);
                    }
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Notification Card
// ─────────────────────────────────────────────────────────────────────────────

class _NotificationCard extends ConsumerWidget {
  const _NotificationCard({
    required this.notification,
    required this.isRead,
    required this.onTap,
  });

  final AppNotification notification;
  final bool isRead;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isAdmin = notification.isAdminType;
    final accent = isAdmin ? const Color(0xFF00BFA5) : const Color(0xFF246BFD);
    final bgColor = isRead
        ? Colors.transparent
        : (isDark
            ? accent.withValues(alpha: 0.08)
            : accent.withValues(alpha: 0.05));

    final senderLabel = isAdmin
        ? 'System Notification'
        : 'From: ${notification.senderName ?? 'Manager'}';

    final userModel = ref.watch(currentUserModelProvider).valueOrNull;
    final isCurrentUserAdmin = userModel?.isAdmin ?? false;
    final isCurrentUserManager = userModel?.isManager ?? false;
    final authUser = ref.watch(authStateProvider).valueOrNull;
    final notificationService = ref.read(notificationServiceProvider);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isRead
                  ? (isDark
                      ? const Color(0xFF2A2A2A)
                      : const Color(0xFFE0E0E0))
                  : accent.withValues(alpha: 0.35),
              width: isRead ? 1 : 1.5,
            ),
          ),
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon
              Container(
                margin: const EdgeInsets.only(top: 2),
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isAdmin
                      ? Icons.campaign_rounded
                      : Icons.person_pin_rounded,
                  color: accent,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            style: TextStyle(
                              fontWeight: isRead
                                  ? FontWeight.w500
                                  : FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        if (!isRead)
                          Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.only(left: 6, top: 4),
                            decoration: BoxDecoration(
                              color: accent,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notification.body,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark
                            ? Colors.grey.shade400
                            : Colors.grey.shade700,
                      ),
                    ),
                    if (notification.link != null) ...[
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: () async {
                          final uri = Uri.tryParse(notification.link!);
                          if (uri != null) {
                            await launchUrl(uri, mode: LaunchMode.externalApplication);
                          }
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.link_rounded, size: 16, color: accent),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                notification.link!,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: accent,
                                  fontWeight: FontWeight.w600,
                                  decoration: TextDecoration.underline,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          isAdmin
                              ? Icons.shield_outlined
                              : Icons.person_outline,
                          size: 13,
                          color: accent,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          senderLabel,
                          style: TextStyle(
                            fontSize: 11,
                            color: accent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          _formatRelative(notification.createdAt),
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark
                                ? Colors.grey.shade500
                                : Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Trailing Actions
              if (authUser != null)
                Column(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, size: 20),
                      color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                      tooltip: 'Delete notification',
                      onPressed: () {
                        notificationService.markAsDeleted(notification.id, authUser.uid);
                      },
                    ),
                    if (isCurrentUserAdmin || (isCurrentUserManager && notification.senderId == authUser.uid))
                      IconButton(
                        icon: const Icon(Icons.delete_forever_rounded, size: 20),
                        color: Colors.red.shade400,
                        tooltip: 'Delete for everyone',
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (c) => AlertDialog(
                              title: const Text('Delete Globally?'),
                              content: const Text('This will permanently delete the notification for ALL users.'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(c, false),
                                  child: const Text('Cancel'),
                                ),
                                FilledButton(
                                  style: FilledButton.styleFrom(backgroundColor: Colors.red),
                                  onPressed: () => Navigator.pop(c, true),
                                  child: const Text('Delete Globally'),
                                ),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            await notificationService.deleteGlobally(notification.id);
                          }
                        },
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

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

String _formatRelative(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inSeconds < 60) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return DateFormat('d MMM').format(dt);
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty State
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF1E1E1E)
                    : const Color(0xFFF5F5F5),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.notifications_none_rounded,
                size: 52,
                color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No Notifications',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'You\'re all caught up! New announcements and\nmessages will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
