import 'package:flutter/material.dart';

import '../../../core/widgets/web_layout.dart';

class RoleManagementScreen extends StatefulWidget {
  const RoleManagementScreen({super.key});

  @override
  State<RoleManagementScreen> createState() => _RoleManagementScreenState();
}

class _RoleManagementScreenState extends State<RoleManagementScreen> {
  final Map<String, List<String>> _rolePermissions = {
    'Admin': [
      'Full System Access',
      'Manage All Users & Roles',
      'Configure Geofence & QR Parameters',
      'Generate Dynamic QR Codes',
      'Export PDF & Excel Reports',
      'View Real-time Attendance Analytics',
    ],
    'Manager': [
      'View Department Attendance Logs',
      'Generate Dynamic QR Codes',
      'Export Department PDF & Excel Reports',
      'View Department Analytics',
    ],
    'Employee': [
      'Scan Dynamic QR Codes',
      'View Personal Attendance History',
      'Manage Personal Profile',
      'Customize Personal App Settings',
    ],
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Role & Permission Management'),
      ),
      body: WebLayout(
        child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.4),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.shield_outlined, color: Theme.of(context).colorScheme.primary, size: 36),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      'Access Control Matrix allows administrators to review and enforce role permissions across the application.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          ..._rolePermissions.entries.map((entry) {
            final roleName = entry.key;
            final permissions = entry.value;
            final color = _getRoleColor(roleName);

            return Card(
              margin: const EdgeInsets.only(bottom: 16),
              child: ExpansionTile(
                leading: CircleAvatar(
                  backgroundColor: color.withValues(alpha: 0.2),
                  child: Icon(_getRoleIcon(roleName), color: color),
                ),
                title: Text(
                  '$roleName Role',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                subtitle: Text('${permissions.length} active permissions'),
                children: [
                  const Divider(),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: permissions.map((perm) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Icon(Icons.check_circle_rounded, color: Colors.green.shade600, size: 18),
                              const SizedBox(width: 10),
                              Expanded(child: Text(perm)),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
        ),
      ),
    );
  }

  Color _getRoleColor(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return Colors.purple;
      case 'manager':
        return Colors.blue;
      default:
        return Colors.teal;
    }
  }

  IconData _getRoleIcon(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return Icons.admin_panel_settings;
      case 'manager':
        return Icons.supervisor_account;
      default:
        return Icons.badge;
    }
  }
}
