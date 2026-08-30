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
                        ? [const Color(0xFF202020), const Color(0xFF181818)]
                        : [
                            const Color.fromARGB(255, 79, 155, 131),
                            const Color.fromARGB(255, 79, 155, 131),
                          ],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: isDark
                      ? Border.all(color: const Color(0xFF313131))
                      : null,
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
              const SizedBox(height: 24),
              Text(
                ref.tr('managementTools'),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 16),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 0.9,
                children: [
                  _AdminCard(
                    title: ref.tr('userManagement'),
                    subtitle: ref.tr('userManagementSub'),
                    icon: Icons.people_alt_outlined,
                    color: Colors.blue,
                    onTap: () => context.push('/admin/users'),
                  ),
                  _AdminCard(
                    title: ref.tr('rolePermissions'),
                    subtitle: ref.tr('rolePermissionsSub'),
                    icon: Icons.shield_outlined,
                    color: Colors.purple,
                    onTap: () => context.push('/admin/roles'),
                  ),
                  _AdminCard(
                    title: ref.tr('dynamicQrRotator'),
                    subtitle: ref.tr('dynamicQrRotatorSub'),
                    icon: Icons.qr_code_2_rounded,
                    color: Colors.orange,
                    onTap: () => context.push('/admin/qr'),
                  ),
                  _AdminCard(
                    title: ref.tr('reportsAnalyticsTitle'),
                    subtitle: ref.tr('reportsAnalyticsSub'),
                    icon: Icons.bar_chart_rounded,
                    color: Colors.green,
                    onTap: () => context.push('/admin/reports'),
                  ),
                  _AdminCard(
                    title: ref.tr('systemGeofence'),
                    subtitle: ref.tr('systemGeofenceSub'),
                    icon: Icons.settings_applications_rounded,
                    color: Colors.teal,
                    onTap: () => context.push('/admin/settings'),
                  ),
                  _AdminCard(
                    title: ref.tr('sendNotification'),
                    subtitle: ref.tr('sendNotificationSub'),
                    icon: Icons.campaign_rounded,
                    color: Colors.deepPurple,
                    onTap: () => context.push('/admin/notifications'),
                  ),
                  _AdminCard(
                    title: ref.tr('googleSheetsAttendance'),
                    subtitle: ref.tr('googleSheetsAttendanceSub'),
                    icon: Icons.table_chart_rounded,
                    color: Colors.lightGreen.shade700,
                    onTap: () => context.push('/admin/google-sheets'),
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

class _AdminCard extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, size: 28, color: color),
              ),
              const Spacer(),
              Text(
                title,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
