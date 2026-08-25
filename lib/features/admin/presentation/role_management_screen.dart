import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/app_translations.dart';
import '../../../core/widgets/web_layout.dart';
import '../../auth/domain/auth_provider.dart';

class RoleManagementScreen extends ConsumerStatefulWidget {
  const RoleManagementScreen({super.key});

  @override
  ConsumerState<RoleManagementScreen> createState() =>
      _RoleManagementScreenState();
}

class _RoleManagementScreenState extends ConsumerState<RoleManagementScreen> {
  Map<String, List<String>> _getLocalizedRolePermissions() {
    return {
      'Admin': ref.tr('roleAdminPerms').split('|'),
      'Manager': ref.tr('roleManagerPerms').split('|'),
      'Employee': ref.tr('roleEmployeePerms').split('|'),
    };
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserModelProvider).valueOrNull;
    final isAdmin = currentUser?.isAdmin ?? false;
    final rolePermissions = _getLocalizedRolePermissions();

    final rolesToDisplay = rolePermissions.entries.where((entry) {
      if (!isAdmin && entry.key.toLowerCase() == 'admin') {
        return false;
      }
      return true;
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(ref.tr('rolePermissionManagement')),
      ),
      body: WebLayout(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              color: Theme.of(context)
                  .colorScheme
                  .primaryContainer
                  .withValues(alpha: 0.4),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      Icons.shield_outlined,
                      color: Theme.of(context).colorScheme.primary,
                      size: 36,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        ref.tr('accessControlMatrixDesc'),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            ...rolesToDisplay.map((entry) {
              final roleKey = entry.key;
              final roleName = roleKey == 'Admin'
                  ? ref.tr('roleAdmin')
                  : (roleKey == 'Manager'
                      ? ref.tr('roleManager')
                      : ref.tr('roleEmployee'));
              final permissions = entry.value;
              final color = _getRoleColor(roleKey);

              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                child: ExpansionTile(
                  leading: CircleAvatar(
                    backgroundColor: color.withValues(alpha: 0.2),
                    child: Icon(_getRoleIcon(roleKey), color: color),
                  ),
                  title: Text(
                    '$roleName ${ref.tr('role')}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  subtitle: Text(
                    '${permissions.length} ${ref.tr('activePermissions')}',
                  ),
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
                                Icon(
                                  Icons.check_circle_rounded,
                                  color: Colors.green.shade600,
                                  size: 18,
                                ),
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
