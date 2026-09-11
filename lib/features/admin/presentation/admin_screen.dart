import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/web_layout.dart';
import '../../auth/domain/auth_provider.dart';

import '../../../core/services/app_translations.dart';

class AdminScreen extends ConsumerWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentUser = ref.watch(currentUserModelProvider).valueOrNull;
    final isAdmin = currentUser?.isAdmin ?? false;

    final appBarTitle =
        isAdmin ? ref.tr('adminPanelHub') : ref.tr('managerPanelHub');
    final portalTitle =
        isAdmin ? ref.tr('administratorPortal') : ref.tr('managerPortal');

    return Scaffold(
      appBar: AppBar(
        title: Text(appBarTitle),
      ),
      body: WebLayout(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? [const Color(0xFF1E2238), const Color(0xFF111827)]
                        : [const Color(0xFF4F46E5), const Color(0xFF6366F1)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: isDark
                        ? const Color(0xFF1F293D)
                        : const Color(0xFF4338CA).withValues(alpha: 0.25),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isDark
                          ? const Color.fromRGBO(0, 0, 0, 0.35)
                          : const Color(0xFF4F46E5).withValues(alpha: 0.22),
                      blurRadius: isDark ? 6 : 18,
                      offset: isDark ? const Offset(0, 2) : const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const CircleAvatar(
                      radius: 28,
                      backgroundColor: Colors.white24,
                      child: Icon(
                        Icons.admin_panel_settings,
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
                            portalTitle,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            ref.tr('adminPortalDesc'),
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              Text(
                ref.tr('managementTools'),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.4,
                    ),
              ),
              const SizedBox(height: 16),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                childAspectRatio: 0.95,
                children: [
                  _AdminCard(
                    title: ref.tr('userManagement'),
                    subtitle: ref.tr('userManagementSub'),
                    icon: Icons.people_alt_rounded,
                    color: const Color(0xFF3B82F6),
                    onTap: () => context.push('/admin/users'),
                  ),
                  _AdminCard(
                    title: ref.tr('rolePermissions'),
                    subtitle: ref.tr('rolePermissionsSub'),
                    icon: Icons.shield_rounded,
                    color: const Color(0xFF8B5CF6),
                    onTap: () => context.push('/admin/roles'),
                  ),
                  _AdminCard(
                    title: ref.tr('dynamicQrRotator'),
                    subtitle: ref.tr('dynamicQrRotatorSub'),
                    icon: Icons.qr_code_2_rounded,
                    color: const Color(0xFFF59E0B),
                    onTap: () => context.push('/admin/qr'),
                  ),
                  _AdminCard(
                    title: ref.tr('reportsAnalyticsTitle'),
                    subtitle: ref.tr('reportsAnalyticsSub'),
                    icon: Icons.bar_chart_rounded,
                    color: const Color(0xFF10B981),
                    onTap: () => context.push('/admin/reports'),
                  ),
                  _AdminCard(
                    title: ref.tr('systemGeofence'),
                    subtitle: ref.tr('systemGeofenceSub'),
                    icon: Icons.settings_applications_rounded,
                    color: const Color(0xFF14B8A6),
                    onTap: () => context.push('/admin/settings'),
                  ),
                  _AdminCard(
                    title: ref.tr('sendNotification'),
                    subtitle: ref.tr('sendNotificationSub'),
                    icon: Icons.campaign_rounded,
                    color: const Color(0xFF6366F1),
                    onTap: () => context.push('/admin/notifications'),
                  ),
                  _AdminCard(
                    title: ref.tr('googleSheetsAttendance'),
                    subtitle: ref.tr('googleSheetsAttendanceSub'),
                    icon: Icons.table_chart_rounded,
                    color: const Color(0xFF059669),
                    onTap: () => context.push('/admin/google-sheets'),
                  ),
                  if (isAdmin)
                    _AdminCard(
                      title: ref.tr('mobileAppManagement'),
                      subtitle: ref.tr('mobileAppManagementDesc'),
                      icon: Icons.phone_android_rounded,
                      color: const Color(0xFF0EA5E9),
                      onTap: () => context.push('/admin/mobile-app'),
                    ),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdminCard extends StatefulWidget {
  const _AdminCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  State<_AdminCard> createState() => _AdminCardState();
}

class _AdminCardState extends State<_AdminCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final borderColor = isDark
        ? (_isHovered
            ? widget.color.withValues(alpha: 0.6)
            : const Color(0xFF1E293B))
        : (_isHovered
            ? widget.color.withValues(alpha: 0.5)
            : const Color(0xFFE2E8F0));

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF131B2E) : Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: borderColor, width: _isHovered ? 1.5 : 1),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? (_isHovered
                      ? widget.color.withValues(alpha: 0.2)
                      : const Color.fromRGBO(0, 0, 0, 0.35))
                  : (_isHovered
                      ? widget.color.withValues(alpha: 0.12)
                      : const Color.fromRGBO(15, 23, 42, 0.05)),
              blurRadius: _isHovered ? 16 : 8,
              offset: _isHovered ? const Offset(0, 6) : const Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: widget.onTap,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: widget.color
                              .withValues(alpha: isDark ? 0.2 : 0.12),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: widget.color
                                .withValues(alpha: isDark ? 0.35 : 0.2),
                          ),
                        ),
                        child: Icon(widget.icon, size: 24, color: widget.color),
                      ),
                      Icon(
                        Icons.arrow_outward_rounded,
                        size: 18,
                        color: isDark
                            ? const Color(0xFF64748B)
                            : const Color(0xFF94A3B8),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    widget.title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark
                          ? const Color(0xFF94A3B8)
                          : const Color(0xFF64748B),
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
