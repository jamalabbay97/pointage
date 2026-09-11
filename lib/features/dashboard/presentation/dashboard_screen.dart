import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/models/user_model.dart';
import '../../../core/services/app_translations.dart';
import '../../../core/widgets/bento_card.dart';
import '../../../core/widgets/web_layout.dart';
import '../../admin/presentation/widgets/work_schedule_wizard_dialog.dart';
import '../../attendance/domain/offline_sync_service.dart';
import '../../auth/domain/auth_provider.dart';
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
    final userModelAsync = ref.watch(currentUserModelProvider);
    final userModel = userModelAsync.valueOrNull ??
        (user != null
            ? UserModel(
                uid: user.uid,
                email: user.email ?? '',
                displayName: user.displayName ??
                    (user.email?.split('@').first ?? 'Employee'),
                role: 'employee',
                status: 'active',
                department: 'General',
              )
            : null);
    _checkFirstLoginWizard(userModel);
    final isAdminOrManager = userModel?.isAdminOrManager ?? false;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final effectiveUid = user?.uid ?? userModel?.uid ?? '';
    final todayDocId =
        '$effectiveUid-${now.toIso8601String().substring(0, 10)}';
    final dashAvatarImage = ProfileScreen.getProfileImageProvider(
      userModel?.photoUrl ?? user?.photoURL,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(ref.tr('dashboard')),
        actions: [
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
            await ref.read(offlineSyncServiceProvider).syncPendingRecords();
          },
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // Redesigned Modern Executive Welcome Card
              _ModernWelcomeCard(
                userModel: userModel,
                user: user,
                effectiveUid: effectiveUid,
                dashAvatarImage: dashAvatarImage,
                now: now,
                todayDocId: todayDocId,
                isDark: isDark,
              ),
              const SizedBox(height: 20),

              // Main Scan Hero Card
              if (userModel?.isEmployee == true)
                Builder(
                  builder: (context) {
                    final empSchedule =
                        (userModel?.scheduleType ?? 'standard').toLowerCase();
                    final isWeekend = now.weekday == DateTime.saturday ||
                        now.weekday == DateTime.sunday;
                    final isStandardWeekend =
                        empSchedule == 'standard' && isWeekend;

                    return Container(
                      decoration: BoxDecoration(
                        gradient: isDark
                            ? const LinearGradient(
                                colors: [Color(0xFF1E1B4B), Color(0xFF131B2E)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              )
                            : const LinearGradient(
                                colors: [Color(0xFFEEF2FF), Color(0xFFE0E7FF)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: Theme.of(context)
                              .colorScheme
                              .primary
                              .withValues(alpha: isDark ? 0.35 : 0.25),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Theme.of(context)
                                .colorScheme
                                .primary
                                .withValues(alpha: isDark ? 0.25 : 0.12),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(24),
                          onTap: () => context.push('/scan'),
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: isStandardWeekend
                                          ? const [
                                              Color(0xFF8B5CF6),
                                              Color(0xFFA78BFA),
                                            ]
                                          : const [
                                              Color(0xFF4F46E5),
                                              Color(0xFF6366F1),
                                            ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: [
                                      BoxShadow(
                                        color: (isStandardWeekend
                                                ? const Color(0xFF8B5CF6)
                                                : const Color(0xFF4F46E5))
                                            .withValues(alpha: 0.4),
                                        blurRadius: 12,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    isStandardWeekend
                                        ? Icons.weekend_rounded
                                        : Icons.qr_code_scanner_rounded,
                                    color: Colors.white,
                                    size: 32,
                                  ),
                                ),
                                const SizedBox(width: 18),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        ref.tr('scanQrCode'),
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: -0.3,
                                            ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        isStandardWeekend
                                            ? ref.tr('weekendDayOff')
                                            : ref.tr('registerGps'),
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: isStandardWeekend
                                                  ? const Color(0xFF8B5CF6)
                                                  : (isDark
                                                      ? const Color(0xFF94A3B8)
                                                      : const Color(
                                                          0xFF64748B,
                                                        )),
                                              fontWeight: isStandardWeekend
                                                  ? FontWeight.w600
                                                  : FontWeight.normal,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .primary
                                        .withValues(alpha: 0.12),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.arrow_forward_rounded,
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                    size: 20,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),

              // Today's Activity Details Card (Employee Only)
              if (userModel?.isEmployee == true) ...[
                const SizedBox(height: 24),
                _TodayActivityCard(
                  effectiveUid: effectiveUid,
                  now: now,
                  scheduleType: userModel?.scheduleType ?? 'standard',
                ),
              ],

              // Admin Control Hub (Single canonical entry point for Admins / Managers)
              if (isAdminOrManager) ...[
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      ref.tr('adminPortal'),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.4,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                BentoCard(
                  title: ref.tr('adminPortal'),
                  subtitle: ref.tr('reportsAnalytics'),
                  icon: Icons.admin_panel_settings_rounded,
                  accentColor: const Color(0xFFF59E0B),
                  badgeText: 'Admin',
                  onTap: () => context.push('/admin'),
                ),
              ],
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModernWelcomeCard extends ConsumerWidget {
  const _ModernWelcomeCard({
    required this.userModel,
    required this.user,
    required this.effectiveUid,
    required this.dashAvatarImage,
    required this.now,
    required this.todayDocId,
    required this.isDark,
  });

  final UserModel? userModel;
  final User? user;
  final String effectiveUid;
  final ImageProvider? dashAvatarImage;
  final DateTime now;
  final String todayDocId;
  final bool isDark;

  static String _formatGreeting(WidgetRef ref, DateTime now) {
    final h = now.hour;
    if (h < 12) return ref.tr('goodMorning');
    if (h < 18) return ref.tr('goodAfternoon');
    return ref.tr('goodEvening');
  }

  static IconData _getGreetingIcon(DateTime now) {
    final h = now.hour;
    if (h < 12) return Icons.wb_sunny_rounded;
    if (h < 18) return Icons.wb_twilight_rounded;
    return Icons.nights_stay_rounded;
  }

  static String _formatDisplayName(UserModel? userModel, User? user) {
    String? raw = userModel?.displayName;
    if (raw == null || raw.trim().isEmpty) {
      raw = user?.displayName;
    }
    if (raw == null || raw.trim().isEmpty) {
      raw = user?.email;
    }
    if (raw == null || raw.trim().isEmpty) {
      raw = userModel?.email;
    }
    if (raw == null || raw.trim().isEmpty) return 'Employee';

    String clean = raw.contains('@') ? raw.split('@').first : raw;
    clean = clean.replaceAll(RegExp(r'[._-]+'), ' ').trim();
    if (clean.isEmpty) return 'Employee';

    return clean
        .split(' ')
        .where((w) => w.isNotEmpty)
        .map(
          (w) =>
              w[0].toUpperCase() +
              (w.length > 1 ? w.substring(1).toLowerCase() : ''),
        )
        .join(' ');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final greeting = _formatGreeting(ref, now);
    final greetingIcon = _getGreetingIcon(now);
    final displayName = _formatDisplayName(userModel, user);
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : 'E';
    final role = (userModel?.role ?? 'employee').toUpperCase();
    final department = userModel?.department ?? 'General';
    final displayId = (userModel?.uid ?? effectiveUid);
    final shortId =
        displayId.length > 8 ? displayId.substring(0, 8) : displayId;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: isDark
            ? const LinearGradient(
                colors: [
                  Color(0xFF0F172A),
                  Color(0xFF1E1B4B),
                  Color(0xFF312E81),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : const LinearGradient(
                colors: [
                  Color(0xFF1E40AF),
                  Color(0xFF3B82F6),
                  Color(0xFF6366F1),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        border: Border.all(
          color: Colors.white.withValues(alpha: isDark ? 0.15 : 0.25),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: (isDark ? const Color(0xFF1E1B4B) : const Color(0xFF3B82F6))
                .withValues(alpha: isDark ? 0.35 : 0.28),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            // Decorative background ambient bubbles
            Positioned(
              top: -35,
              right: -35,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.07),
                ),
              ),
            ),
            Positioned(
              bottom: -40,
              left: -30,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.05),
                ),
              ),
            ),
            // Card Content
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Profile Row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Avatar with ring and active status dot
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(2.5),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [
                                  Colors.white.withValues(alpha: 0.85),
                                  Colors.white.withValues(alpha: 0.25),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.15),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: CircleAvatar(
                              radius: 26,
                              backgroundColor:
                                  Colors.white.withValues(alpha: 0.2),
                              backgroundImage: dashAvatarImage,
                              child: dashAvatarImage == null
                                  ? Text(
                                      initial,
                                      style: const TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    )
                                  : null,
                            ),
                          ),
                          Positioned(
                            bottom: 1,
                            right: 1,
                            child: Container(
                              width: 13,
                              height: 13,
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981),
                                shape: BoxShape.circle,
                                border:
                                    Border.all(color: Colors.white, width: 2),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 14),
                      // Greeting, Name & Role/Dept
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  greetingIcon,
                                  size: 13,
                                  color: Colors.amberAccent,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  greeting,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.85),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.18),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color:
                                          Colors.white.withValues(alpha: 0.3),
                                      width: 0.8,
                                    ),
                                  ),
                                  child: Text(
                                    role,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.6,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 21,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.4,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                Icon(
                                  Icons.apartment_rounded,
                                  size: 12,
                                  color: Colors.white.withValues(alpha: 0.7),
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    department,
                                    style: TextStyle(
                                      color:
                                          Colors.white.withValues(alpha: 0.75),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '•',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.5),
                                    fontSize: 11,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'ID: $shortId',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.75),
                                    fontSize: 11,
                                    fontFamily: 'monospace',
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),

                  // Bottom Frosted Bar: Live Digital Clock & Attendance Status Pill
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color:
                          Colors.black.withValues(alpha: isDark ? 0.3 : 0.12),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.12),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Live Clock & Date
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 7,
                                  height: 7,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF34D399),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  DateFormat('HH:mm:ss').format(now),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                    fontFamily: 'monospace',
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              DateFormat('EEEE, MMM d, y').format(now),
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.8),
                                fontSize: 10.5,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),

                        // Today's Status Indicator: Live Attendance for Employees, System Online for Supervisors
                        userModel?.isEmployee == true
                            ? _buildAttendanceStatusPill(ref)
                            : _buildAdminStatusPill(ref),
                      ],
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

  Widget _buildAdminStatusPill(WidgetRef ref) {
    const pillColor = Color(0xFF10B981);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: pillColor.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: pillColor.withValues(alpha: 0.45),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.verified_user_rounded, size: 13, color: pillColor),
          const SizedBox(width: 5),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 120),
            child: Text(
              ref.tr('systemOnline'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: pillColor,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceStatusPill(WidgetRef ref) {
    final scheduleType = (userModel?.scheduleType ?? 'standard').toLowerCase();
    final isWeekend =
        now.weekday == DateTime.saturday || now.weekday == DateTime.sunday;
    final isStandardWeekend = scheduleType == 'standard' && isWeekend;

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: ref.watch(offlineSyncServiceProvider).getPendingRecords(),
      builder: (context, pendingSnap) {
        final pendingRecords = pendingSnap.data ?? [];
        final todayStr = now.toIso8601String().substring(0, 10);
        final localPendingToday = pendingRecords.firstWhere(
          (r) =>
              r['docId'] == todayDocId ||
              (r['employeeId'] == effectiveUid && r['date'] == todayStr),
          orElse: () => <String, dynamic>{},
        );

        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('attendance')
              .doc(todayDocId)
              .snapshots(),
          builder: (context, snapshot) {
            final data = snapshot.data?.data() as Map<String, dynamic>?;
            final exists = (snapshot.data?.exists ?? false) ||
                localPendingToday.isNotEmpty;
            final record =
                localPendingToday.isNotEmpty ? localPendingToday : (data ?? {});

            final status = (record['status'] as String? ?? '').toLowerCase();
            final isAbsent = exists && status == 'absent';
            final rawCheckIn = record['time'] ?? record['timestamp'];
            final rawCheckOut = record['checkoutTime'];

            final checkInTime = _TodayActivityCard._formatTime(rawCheckIn);
            final checkOutTime = _TodayActivityCard._formatTime(rawCheckOut);

            final hasCheckedIn = exists && !isAbsent && checkInTime != '-';
            final hasCheckedOut = rawCheckOut != null && checkOutTime != '-';

            Color pillColor;
            IconData pillIcon;
            String pillLabel;

            if (hasCheckedOut) {
              pillColor = const Color(0xFF10B981);
              pillIcon = Icons.check_circle_rounded;
              pillLabel = ref.tr('shiftCompleted');
            } else if (hasCheckedIn) {
              pillColor = const Color(0xFF38BDF8);
              pillIcon = Icons.timelapse_rounded;
              pillLabel = ref.tr('shiftInProgress');
            } else if (isAbsent) {
              pillColor = const Color(0xFFEF4444);
              pillIcon = Icons.cancel_rounded;
              pillLabel = ref.tr('absentToday');
            } else if (isStandardWeekend) {
              pillColor = const Color(0xFF8B5CF6);
              pillIcon = Icons.weekend_rounded;
              pillLabel = ref.tr('weekendDayOff');
            } else {
              pillColor = const Color(0xFFFBBF24);
              pillIcon = Icons.radio_button_unchecked_rounded;
              pillLabel = ref.tr('notCheckedIn');
            }

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: pillColor.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: pillColor.withValues(alpha: 0.45),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(pillIcon, size: 13, color: pillColor),
                  const SizedBox(width: 5),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 120),
                    child: Text(
                      pillLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: pillColor,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _TodayActivityCard extends ConsumerWidget {
  const _TodayActivityCard({
    required this.effectiveUid,
    required this.now,
    this.scheduleType = 'standard',
  });

  final String effectiveUid;
  final DateTime now;
  final String scheduleType;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final todayStr = now.toIso8601String().substring(0, 10);
    final todayDocId = '$effectiveUid-$todayStr';
    final normSchedule = scheduleType.toLowerCase();
    final isWeekend =
        now.weekday == DateTime.saturday || now.weekday == DateTime.sunday;
    final isStandardWeekend = normSchedule == 'standard' && isWeekend;
    final monthPrefix = now.toIso8601String().substring(0, 7);

    if (normSchedule == 'days_20_10') {
      return StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('attendance')
            .where('employeeId', isEqualTo: effectiveUid)
            .where('date', isGreaterThanOrEqualTo: '$monthPrefix-01')
            .where('date', isLessThanOrEqualTo: '$monthPrefix-31')
            .snapshots(),
        builder: (context, monthSnap) {
          int count = 0;
          if (monthSnap.hasData && monthSnap.data != null) {
            count = monthSnap.data!.docs
                .where(
                  (d) =>
                      ((d.data() as Map<String, dynamic>?)?['status']
                                  as String? ??
                              '')
                          .toLowerCase() !=
                      'absent',
                )
                .length;
          }
          return _buildCardContent(
            context,
            ref,
            isDark: isDark,
            todayDocId: todayDocId,
            todayStr: todayStr,
            isStandardWeekend: false,
            normSchedule: normSchedule,
            monthlyCount: count,
          );
        },
      );
    }

    return _buildCardContent(
      context,
      ref,
      isDark: isDark,
      todayDocId: todayDocId,
      todayStr: todayStr,
      isStandardWeekend: isStandardWeekend,
      normSchedule: normSchedule,
      monthlyCount: 0,
    );
  }

  Widget _buildCardContent(
    BuildContext context,
    WidgetRef ref, {
    required bool isDark,
    required String todayDocId,
    required String todayStr,
    required bool isStandardWeekend,
    required String normSchedule,
    required int monthlyCount,
  }) {
    final is2010QuotaReached =
        normSchedule == 'days_20_10' && monthlyCount >= 20;

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: ref.watch(offlineSyncServiceProvider).getPendingRecords(),
      builder: (context, pendingSnap) {
        final pendingRecords = pendingSnap.data ?? [];
        final localPendingToday = pendingRecords.firstWhere(
          (r) =>
              r['docId'] == todayDocId ||
              (r['employeeId'] == effectiveUid && r['date'] == todayStr),
          orElse: () => <String, dynamic>{},
        );

        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('attendance')
              .doc(todayDocId)
              .snapshots(),
          builder: (context, snapshot) {
            final data = snapshot.data?.data() as Map<String, dynamic>?;
            final exists = (snapshot.data?.exists ?? false) ||
                localPendingToday.isNotEmpty;
            final record =
                localPendingToday.isNotEmpty ? localPendingToday : (data ?? {});

            final status = (record['status'] as String? ?? '').toLowerCase();
            final isAbsent = exists && status == 'absent';
            final rawCheckIn = record['time'] ?? record['timestamp'];
            final rawCheckOut = record['checkoutTime'];

            final checkInTime = _formatTime(rawCheckIn);
            final checkOutTime = _formatTime(rawCheckOut);

            final hasCheckedIn = exists && !isAbsent && checkInTime != '-';
            final hasCheckedOut = rawCheckOut != null && checkOutTime != '-';

            // Calculate duration
            String durationStr = '-';
            if (hasCheckedIn) {
              final inDt = _parseDateTime(rawCheckIn, now);
              if (inDt != null) {
                final endDt = hasCheckedOut
                    ? (_parseDateTime(rawCheckOut, now) ?? now)
                    : now;
                final diff = endDt.difference(inDt);
                if (!diff.isNegative) {
                  final hours = diff.inHours;
                  final minutes = diff.inMinutes % 60;
                  durationStr =
                      '${hours}h ${minutes.toString().padLeft(2, '0')}m';
                }
              }
            }

            final isRestDay = isStandardWeekend || is2010QuotaReached;

            return Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF131B2E) : Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isDark
                      ? const Color(0xFF1E293B)
                      : const Color(0xFFE2E8F0),
                ),
                boxShadow: [
                  BoxShadow(
                    color: isDark
                        ? const Color.fromRGBO(0, 0, 0, 0.3)
                        : const Color.fromRGBO(15, 23, 42, 0.05),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF3B82F6).withValues(
                            alpha: isDark ? 0.2 : 0.12,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.schedule_rounded,
                          color: Color(0xFF3B82F6),
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          ref.tr('todayActivity'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                      if (normSchedule == 'days_20_10') ...[
                        const SizedBox(width: 6),
                        _ActivityStatusBadge(
                          label: '$monthlyCount/20',
                          color: monthlyCount >= 20
                              ? const Color(0xFF10B981)
                              : const Color(0xFF6366F1),
                          icon: Icons.calendar_month_rounded,
                        ),
                      ],
                      const SizedBox(width: 8),
                      if (hasCheckedOut)
                        _ActivityStatusBadge(
                          label: ref.tr('shiftCompleted'),
                          color: const Color(0xFF10B981),
                          icon: Icons.check_circle_rounded,
                        )
                      else if (hasCheckedIn)
                        _ActivityStatusBadge(
                          label: ref.tr('shiftInProgress'),
                          color: const Color(0xFF3B82F6),
                          icon: Icons.timelapse_rounded,
                        )
                      else if (isStandardWeekend)
                        _ActivityStatusBadge(
                          label: ref.tr('weekendDayOff'),
                          color: const Color(0xFF8B5CF6),
                          icon: Icons.weekend_rounded,
                        )
                      else if (is2010QuotaReached)
                        _ActivityStatusBadge(
                          label: ref.tr('monthlyQuotaReached'),
                          color: const Color(0xFF8B5CF6),
                          icon: Icons.event_available_rounded,
                        )
                      else
                        _ActivityStatusBadge(
                          label: ref.tr('notCheckedIn'),
                          color: const Color(0xFF94A3B8),
                          icon: Icons.radio_button_unchecked_rounded,
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(height: 1),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _ActivityTimeBox(
                          icon: Icons.login_rounded,
                          iconColor: const Color(0xFF10B981),
                          label: ref.tr('checkInTime'),
                          value: checkInTime,
                          isDark: isDark,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _ActivityTimeBox(
                          icon: Icons.logout_rounded,
                          iconColor: const Color(0xFF3B82F6),
                          label: ref.tr('checkOutTime'),
                          value: checkOutTime,
                          isDark: isDark,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _ActivityTimeBox(
                          icon: Icons.hourglass_top_rounded,
                          iconColor: const Color(0xFF8B5CF6),
                          label: ref.tr('workDuration'),
                          value: durationStr,
                          isDark: isDark,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF0F172A)
                          : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          hasCheckedIn
                              ? Icons.verified_user_rounded
                              : (isRestDay
                                  ? Icons.beach_access_rounded
                                  : Icons.info_outline_rounded),
                          size: 15,
                          color: hasCheckedIn
                              ? const Color(0xFF10B981)
                              : (isRestDay
                                  ? const Color(0xFF8B5CF6)
                                  : const Color(0xFF94A3B8)),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            hasCheckedIn
                                ? ref.tr('verifiedByGpsQr')
                                : (isStandardWeekend
                                    ? ref.tr('restDayMessage')
                                    : (is2010QuotaReached
                                        ? ref.tr('monthlyLimitReached2010')
                                        : ref.tr('notPunchedYet'))),
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark
                                  ? const Color(0xFF94A3B8)
                                  : const Color(0xFF64748B),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  static String _formatTime(Object? value) {
    if (value == null) return '-';
    final raw = value.toString().trim();
    if (raw.isEmpty || raw == '-') return '-';
    final parsed = DateTime.tryParse(raw);
    if (parsed != null) {
      return DateFormat('HH:mm:ss').format(parsed);
    }
    return raw;
  }

  static DateTime? _parseDateTime(Object? value, DateTime fallbackDay) {
    if (value == null) return null;
    final raw = value.toString().trim();
    final parsed = DateTime.tryParse(raw);
    if (parsed != null) return parsed;
    final parts = raw.split(':');
    if (parts.length >= 2) {
      final h = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1]);
      final s = parts.length > 2 ? int.tryParse(parts[2]) : 0;
      if (h != null && m != null) {
        return DateTime(
          fallbackDay.year,
          fallbackDay.month,
          fallbackDay.day,
          h,
          m,
          s ?? 0,
        );
      }
    }
    return null;
  }
}

class _ActivityStatusBadge extends StatelessWidget {
  const _ActivityStatusBadge({
    required this.label,
    required this.color,
    required this.icon,
  });

  final String label;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.2 : 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 110),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityTimeBox extends StatelessWidget {
  const _ActivityTimeBox({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.isDark,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: iconColor),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    color: isDark
                        ? const Color(0xFF94A3B8)
                        : const Color(0xFF64748B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
