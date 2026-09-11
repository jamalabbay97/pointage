import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/domain/auth_provider.dart';
import '../../features/notifications/data/notification_provider.dart';
import '../services/app_translations.dart';

class AppShell extends ConsumerWidget {
  const AppShell({
    super.key,
    required this.child,
    required this.currentLocation,
  });

  final Widget child;
  final String currentLocation;

  int _calculateSelectedIndex(String location, bool isAdminOrManager) {
    if (isAdminOrManager) {
      if (location.startsWith('/admin')) return 1;
    } else {
      if (location.startsWith('/history')) return 1;
    }
    if (location.startsWith('/notifications')) return 2;
    if (location.startsWith('/profile') || location.startsWith('/settings')) {
      return 3;
    }
    return 0; // dashboard
  }

  void _onItemTapped(int index, BuildContext context, bool isAdminOrManager) {
    switch (index) {
      case 0:
        context.go('/dashboard');
        break;
      case 1:
        if (isAdminOrManager) {
          context.go('/admin');
        } else {
          context.go('/history');
        }
        break;
      case 2:
        context.go('/notifications');
        break;
      case 3:
        context.go('/profile');
        break;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final currentUserAsync = ref.watch(currentUserModelProvider);
    final currentUser = currentUserAsync.valueOrNull;
    final isAdminOrManager = currentUser?.isAdminOrManager ?? false;
    final isEmployee = currentUser == null || currentUser.isEmployee;

    final selectedIndex =
        _calculateSelectedIndex(currentLocation, isAdminOrManager);
    final unreadCount = ref.watch(unreadNotificationCountProvider);
    final isWide = MediaQuery.sizeOf(context).width >= 840;

    // On wide desktop/web viewports, render an elegant sidebar rail
    if (isWide) {
      return Scaffold(
        body: Row(
          children: [
            Container(
              width: 240,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : Colors.white,
                border: Border(
                  right: BorderSide(
                    color: isDark
                        ? const Color(0xFF1E293B)
                        : const Color(0xFFE2E8F0),
                  ),
                ),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 24),
                  // App Brand
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF4F46E5), Color(0xFF6366F1)],
                            ),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF4F46E5)
                                    .withValues(alpha: 0.35),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.qr_code_scanner_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Pointage',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                letterSpacing: -0.3,
                              ),
                            ),
                            Text(
                              'Enterprise Portal',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: isDark
                                    ? const Color(0xFF94A3B8)
                                    : const Color(0xFF64748B),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (isEmployee) ...[
                    const SizedBox(height: 28),
                    // Quick Punch Action Button (Employees only)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 3,
                        ),
                        onPressed: () => context.push('/scan'),
                        icon:
                            const Icon(Icons.qr_code_scanner_rounded, size: 20),
                        label: Text(
                          ref.tr('scanQrCode'),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                  ] else ...[
                    const SizedBox(height: 24),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                  ],
                  const SizedBox(height: 16),
                  // Nav Items
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      children: [
                        _SidebarItem(
                          icon: Icons.dashboard_rounded,
                          title: ref.tr('dashboard'),
                          isSelected: selectedIndex == 0,
                          onTap: () =>
                              _onItemTapped(0, context, isAdminOrManager),
                        ),
                        _SidebarItem(
                          icon: isAdminOrManager
                              ? Icons.admin_panel_settings_rounded
                              : Icons.history_rounded,
                          title: isAdminOrManager
                              ? ref.tr('adminPortal')
                              : ref.tr('attendanceHistory'),
                          isSelected: selectedIndex == 1,
                          onTap: () =>
                              _onItemTapped(1, context, isAdminOrManager),
                        ),
                        _SidebarItem(
                          icon: Icons.notifications_none_rounded,
                          activeIcon: Icons.notifications_rounded,
                          title: ref.tr('notifications'),
                          isSelected: selectedIndex == 2,
                          badgeCount: unreadCount,
                          onTap: () =>
                              _onItemTapped(2, context, isAdminOrManager),
                        ),
                        _SidebarItem(
                          icon: Icons.person_outline_rounded,
                          activeIcon: Icons.person_rounded,
                          title: ref.tr('userProfile'),
                          isSelected: selectedIndex == 3,
                          onTap: () =>
                              _onItemTapped(3, context, isAdminOrManager),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(child: child),
          ],
        ),
      );
    }

    // On mobile, render a luxury dock (with center scan button ONLY for employees)
    return Scaffold(
      body: child,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : Colors.white,
          border: Border(
            top: BorderSide(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
              width: 1,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? const Color.fromRGBO(0, 0, 0, 0.4)
                  : const Color.fromRGBO(15, 23, 42, 0.06),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: SizedBox(
            height: 64,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _MobileNavItem(
                  icon: Icons.dashboard_rounded,
                  label: ref.tr('dashboard'),
                  isSelected: selectedIndex == 0,
                  onTap: () => _onItemTapped(0, context, isAdminOrManager),
                ),
                _MobileNavItem(
                  icon: isAdminOrManager
                      ? Icons.admin_panel_settings_rounded
                      : Icons.history_rounded,
                  label: isAdminOrManager
                      ? ref.tr('adminPortal')
                      : ref.tr('attendanceHistory'),
                  isSelected: selectedIndex == 1,
                  onTap: () => _onItemTapped(1, context, isAdminOrManager),
                ),
                // Center Scanner Action Button (Employees ONLY)
                if (isEmployee)
                  GestureDetector(
                    onTap: () => context.push('/scan'),
                    child: Container(
                      width: 50,
                      height: 50,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF4F46E5), Color(0xFF6366F1)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color:
                                const Color(0xFF4F46E5).withValues(alpha: 0.45),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                        border: Border.all(color: Colors.white24, width: 1.5),
                      ),
                      child: const Icon(
                        Icons.qr_code_scanner_rounded,
                        color: Colors.white,
                        size: 26,
                      ),
                    ),
                  ),
                _MobileNavItem(
                  icon: Icons.notifications_rounded,
                  label: ref.tr('notifications'),
                  isSelected: selectedIndex == 2,
                  badgeCount: unreadCount,
                  onTap: () => _onItemTapped(2, context, isAdminOrManager),
                ),
                _MobileNavItem(
                  icon: Icons.person_rounded,
                  label: ref.tr('userProfile'),
                  isSelected: selectedIndex == 3,
                  onTap: () => _onItemTapped(3, context, isAdminOrManager),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MobileNavItem extends StatelessWidget {
  const _MobileNavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.badgeCount = 0,
  });

  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;
    final unselectedColor =
        isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  icon,
                  color: isSelected ? primary : unselectedColor,
                  size: 24,
                ),
                if (badgeCount > 0)
                  Positioned(
                    top: -4,
                    right: -6,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      decoration: const BoxDecoration(
                        color: Color(0xFFEF4444),
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        badgeCount > 99 ? '99+' : '$badgeCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? primary : unselectedColor,
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.icon,
    this.activeIcon,
    required this.title,
    required this.isSelected,
    required this.onTap,
    this.badgeCount = 0,
  });

  final IconData icon;
  final IconData? activeIcon;
  final String title;
  final bool isSelected;
  final VoidCallback onTap;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: isSelected
            ? (isDark
                ? primary.withValues(alpha: 0.18)
                : primary.withValues(alpha: 0.1))
            : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        border: isSelected
            ? Border.all(
                color: isDark
                    ? primary.withValues(alpha: 0.35)
                    : primary.withValues(alpha: 0.25),
              )
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        clipBehavior: Clip.antiAlias,
        borderRadius: BorderRadius.circular(14),
        child: ListTile(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          dense: true,
          leading: Icon(
            isSelected ? (activeIcon ?? icon) : icon,
            color: isSelected
                ? primary
                : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
          ),
          title: Text(
            title,
            style: TextStyle(
              color: isSelected
                  ? (isDark ? Colors.white : primary)
                  : (isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155)),
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              fontSize: 14,
            ),
          ),
          trailing: badgeCount > 0
              ? Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    badgeCount > 99 ? '99+' : '$badgeCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                )
              : null,
          onTap: onTap,
        ),
      ),
    );
  }
}
