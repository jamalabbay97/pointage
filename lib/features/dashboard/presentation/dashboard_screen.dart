import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/services/app_translations.dart';
import '../../../core/services/language_provider.dart';
import '../../../core/widgets/mobile_app_download_dialog.dart';
import '../../../core/widgets/web_layout.dart';
import '../../admin/presentation/widgets/work_schedule_wizard_dialog.dart';
import '../../auth/domain/auth_provider.dart';
import '../../notifications/data/notification_provider.dart';
import '../../profile/presentation/profile_screen.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  DateTime now = DateTime.now();
  Timer? timer;
  bool _wizardShown = false;

  @override
  void initState() {
    super.initState();
    timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) {
        if (mounted) setState(() => now = DateTime.now());
      },
    );
  }

  void _checkFirstLoginWizard(userModel) {
    if (!_wizardShown &&
        userModel != null &&
        userModel.isManager &&
        userModel.isFirstLogin) {
      _wizardShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          WorkScheduleWizardDialog.show(context, userModel);
        }
      });
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final userModel = ref.watch(currentUserModelProvider).valueOrNull;
    _checkFirstLoginWizard(userModel);
    final isAdminOrManager = ref.watch(isAdminOrManagerProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final todayDocId = '${user?.uid}-${now.toIso8601String().substring(0, 10)}';
    final dashAvatarImage = ProfileScreen.getProfileImageProvider(
      userModel?.photoUrl ?? user?.photoURL,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(ref.tr('dashboard')),
        actions: [
          if (isAdminOrManager)
            IconButton(
              onPressed: () => context.push('/admin'),
              icon: const Icon(Icons.admin_panel_settings),
              tooltip: ref.tr('adminPortal'),
            ),
          // Notification bell with unread badge
          Consumer(
            builder: (context, ref, _) {
              final unread = ref.watch(unreadNotificationCountProvider);
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  IconButton(
                    onPressed: () => context.push('/notifications'),
                    icon: const Icon(Icons.notifications_none_rounded),
                    tooltip: ref.tr('notifications'),
                  ),
                  if (unread > 0)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: IgnorePointer(
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          constraints: const BoxConstraints(
                            minWidth: 16,
                            minHeight: 16,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Theme.of(context).scaffoldBackgroundColor,
                              width: 1.5,
                            ),
                          ),
                          child: Text(
                            unread > 99 ? '99+' : '$unread',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          IconButton(
            onPressed: () => context.push('/settings'),
            icon: const Icon(Icons.settings_outlined),
            tooltip: ref.tr('settingsCenter'),
          ),
        ],
      ),
      body: WebLayout(
        child: RefreshIndicator(
          onRefresh: () async {
            setState(() => now = DateTime.now());
          },
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // Welcome Header Card
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? [const Color(0xFF202020), const Color(0xFF181818)]
                        : [
                            const Color.fromARGB(255, 60, 166, 136),
                            const Color.fromARGB(255, 62, 167, 134),
                          ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(28),
                  border: isDark
                      ? Border.all(color: const Color(0xFF313131))
                      : null,
                  boxShadow: [
                    BoxShadow(
                      color: isDark
                          ? const Color.fromRGBO(0, 0, 0, 0.35)
                          : const Color.fromARGB(255, 60, 169, 138)
                              .withValues(alpha: 0.15),
                      blurRadius: isDark ? 2 : 16,
                      offset: isDark ? const Offset(0, 1) : const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 26,
                          backgroundColor: Colors.white24,
                          backgroundImage: dashAvatarImage,
                          child: dashAvatarImage == null
                              ? Text(
                                  (userModel?.displayName.isNotEmpty == true)
                                      ? userModel!.displayName[0].toUpperCase()
                                      : 'E',
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${ref.tr('hello')}, ${userModel?.displayName ?? user?.displayName ?? ref.tr('employee')} 👋',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                '${userModel?.department ?? 'General'} • ID: ${user?.uid.substring(0, 8) ?? 'N/A'}',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            ref
                                .trRole(userModel?.role ?? 'employee')
                                .toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const Divider(color: Colors.white24, height: 1),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              DateFormat.yMMMMEEEEd(
                                ref.watch(languageProvider).code,
                              ).format(now),
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              DateFormat.Hms().format(now),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ],
                        ),
                        if (userModel?.isEmployee == true)
                          StreamBuilder<DocumentSnapshot>(
                            stream: FirebaseFirestore.instance
                                .collection('attendance')
                                .doc(todayDocId)
                                .snapshots(),
                            builder: (context, snapshot) {
                              final data = snapshot.data?.data()
                                  as Map<String, dynamic>?;
                              final exists = snapshot.data?.exists ?? false;
                              final status = (data?['status'] as String? ?? '').toLowerCase();
                              final isAbsent = exists && status == 'absent';
                              final hasCheckedOut = data != null &&
                                  data.containsKey('checkoutTime') &&
                                  data['checkoutTime'] != null;
                              final hasCheckedIn = exists && !isAbsent;

                              String statusText;
                              Color statusColor;
                              IconData statusIcon;

                              if (isAbsent) {
                                statusText = ref.tr('absentToday');
                                statusColor = Colors.red.shade600;
                                statusIcon = Icons.cancel_rounded;
                              } else if (hasCheckedOut) {
                                statusText = ref.tr('checkedOutToday');
                                statusColor = Colors.blue.shade600;
                                statusIcon = Icons.done_all_rounded;
                              } else if (hasCheckedIn) {
                                statusText = ref.tr('checkedInToday');
                                statusColor = Colors.green.shade600;
                                statusIcon = Icons.check_circle_rounded;
                              } else {
                                statusText = ref.tr('notCheckedIn');
                                statusColor = Colors.orange.shade700;
                                statusIcon = Icons.pending_rounded;
                              }

                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: statusColor,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      statusIcon,
                                      color: Colors.white,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      statusText,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Main Scan Hero Button
              if (userModel?.isEmployee == true)
                InkWell(
                  onTap: () => context.push('/scan'),
                  borderRadius: BorderRadius.circular(24),
                  child: Ink(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .primaryContainer
                          .withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.qr_code_scanner_rounded,
                            color: Colors.white,
                            size: 32,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                ref.tr('scanQrCode'),
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                ref.tr('registerGps'),
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: Colors.grey.shade600,
                                    ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          color: Theme.of(context).colorScheme.primary,
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ),
              if (userModel?.isEmployee == true) const SizedBox(height: 24),

              Text(
                ref.tr('quickServices'),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 12),

              if (userModel?.isEmployee == true)
                _DashboardActionCard(
                  title: ref.tr('attendanceHistory'),
                  subtitle: ref.tr('viewPunchHistory'),
                  icon: Icons.history_rounded,
                  color: Colors.purple,
                  route: '/history',
                ),
              _DashboardActionCard(
                title: ref.tr('downloadMobileApp'),
                subtitle: ref.tr('mobileAppDownloadSub'),
                icon: Icons.phone_android_rounded,
                color: Colors.indigo,
                onTap: () => MobileAppDownloadDialog.show(context),
              ),
              _DashboardActionCard(
                title: ref.tr('userProfile'),
                subtitle: ref.tr('manageProfile'),
                icon: Icons.person_outline_rounded,
                color: Colors.blue,
                route: '/profile',
              ),
              _DashboardActionCard(
                title: ref.tr('settingsPrefs'),
                subtitle: ref.tr('themeLangSec'),
                icon: Icons.settings_outlined,
                color: Colors.teal,
                route: '/settings',
              ),
              if (isAdminOrManager) ...[
                _DashboardActionCard(
                  title: ref.tr('googleSheetsAttendance'),
                  subtitle: ref.tr('googleSheetsAttendanceSub'),
                  icon: Icons.table_chart_rounded,
                  color: Colors.green.shade700,
                  route: '/admin/google-sheets',
                ),
                _DashboardActionCard(
                  title: ref.tr('adminPortal'),
                  subtitle: ref.tr('reportsAnalytics'),
                  icon: Icons.admin_panel_settings_outlined,
                  color: Colors.amber.shade800,
                  route: '/admin',
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DashboardActionCard extends StatelessWidget {
  const _DashboardActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    this.route,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String? route;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        onTap: () {
          if (onTap != null) {
            onTap!();
          } else if (route != null) {
            context.push(route!);
          }
        },
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: color),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}
