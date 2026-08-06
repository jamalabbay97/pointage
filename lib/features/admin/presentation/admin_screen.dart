import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/web_layout.dart';

class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Panel Hub'),
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
                      : [const Color(0xFF246BFD), const Color(0xFF1952C7)],
                ),
                borderRadius: BorderRadius.circular(24),
                border: isDark ? Border.all(color: const Color(0xFF313131)) : null,
              ),
              child: const Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: Colors.white24,
                    child: Icon(Icons.admin_panel_settings, color: Colors.white, size: 32),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Administrator Portal',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Manage users, security parameters, dynamic QR codes, and enterprise analytics.',
                          style: TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Management Tools',
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
                  title: 'User Management',
                  subtitle: 'Create, edit, enable & disable accounts',
                  icon: Icons.people_alt_outlined,
                  color: Colors.blue,
                  onTap: () => context.push('/admin/users'),
                ),
                _AdminCard(
                  title: 'Role & Permissions',
                  subtitle: 'Access control matrices & role rules',
                  icon: Icons.shield_outlined,
                  color: Colors.purple,
                  onTap: () => context.push('/admin/roles'),
                ),
                _AdminCard(
                  title: 'Dynamic QR Rotator',
                  subtitle: 'HMAC-signed anti-spoofing presenter',
                  icon: Icons.qr_code_2_rounded,
                  color: Colors.orange,
                  onTap: () => context.push('/admin/qr'),
                ),
                _AdminCard(
                  title: 'Reports & Analytics',
                  subtitle: 'Real-time logs, PDF & Excel export',
                  icon: Icons.bar_chart_rounded,
                  color: Colors.green,
                  onTap: () => context.push('/admin/reports'),
                ),
                _AdminCard(
                  title: 'System & Geofence',
                  subtitle: 'Office GPS, radius, HMAC key config',
                  icon: Icons.settings_applications_rounded,
                  color: Colors.teal,
                  onTap: () => context.push('/admin/settings'),
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
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
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
