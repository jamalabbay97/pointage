import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/language_provider.dart';
import '../../../core/theme/theme_provider.dart';
import '../../auth/domain/auth_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _biometricEnabled = true;
  bool _pushNotifications = true;
  bool _dailyReminders = true;
  bool _autoSyncOffline = true;
  String _autoLockTimeout = '5 minutes';

  @override
  Widget build(BuildContext context) {
    final currentThemeMode = ref.watch(themeModeProvider);
    final currentLang = ref.watch(languageProvider);
    final userModel = ref.watch(currentUserModelProvider).valueOrNull;
    final firebaseUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings Center'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // User Card Header
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                    child: Text(
                      (userModel?.displayName.isNotEmpty == true)
                          ? userModel!.displayName[0].toUpperCase()
                          : 'U',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          userModel?.displayName ?? firebaseUser?.displayName ?? 'Employee',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          firebaseUser?.email ?? 'N/A',
                          style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                        ),
                        const SizedBox(height: 4),
                        Chip(
                          visualDensity: VisualDensity.compact,
                          label: Text(
                            (userModel?.role ?? 'employee').toUpperCase(),
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                          backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.arrow_forward_ios, size: 16),
                    onPressed: () => context.push('/profile'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Theme & Appearance
          _buildSectionHeader(context, 'Appearance & Theme', Icons.palette_outlined),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Theme Mode', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  SegmentedButton<ThemeMode>(
                    segments: const [
                      ButtonSegment(
                        value: ThemeMode.light,
                        label: Text('Light'),
                        icon: Icon(Icons.wb_sunny_outlined),
                      ),
                      ButtonSegment(
                        value: ThemeMode.dark,
                        label: Text('Dark'),
                        icon: Icon(Icons.nightlight_round),
                      ),
                      ButtonSegment(
                        value: ThemeMode.system,
                        label: Text('System'),
                        icon: Icon(Icons.settings_suggest_outlined),
                      ),
                    ],
                    selected: {currentThemeMode},
                    onSelectionChanged: (Set<ThemeMode> newSelection) {
                      ref.read(themeModeProvider.notifier).setThemeMode(newSelection.first);
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Language & Localization
          _buildSectionHeader(context, 'Language & Region', Icons.language_outlined),
          Card(
            child: ListTile(
              leading: Text(currentLang.flag, style: const TextStyle(fontSize: 24)),
              title: const Text('Application Language'),
              subtitle: Text(currentLang.name),
              trailing: const Icon(Icons.arrow_drop_down),
              onTap: () => _showLanguagePicker(context),
            ),
          ),
          const SizedBox(height: 20),

          // Account & Security Settings
          _buildSectionHeader(context, 'Account & Security', Icons.lock_outline),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.fingerprint),
                  title: const Text('Biometric Authentication'),
                  subtitle: const Text('Require fingerprint / Face ID on app launch'),
                  value: _biometricEnabled,
                  onChanged: (val) => setState(() => _biometricEnabled = val),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.timer_outlined),
                  title: const Text('Auto-Lock Inactivity Timeout'),
                  subtitle: Text(_autoLockTimeout),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showAutoLockPicker(context),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.password_outlined),
                  title: const Text('Change Account Password'),
                  subtitle: const Text('Send password reset email to account'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _sendPasswordReset(context, firebaseUser?.email),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Notification Settings
          _buildSectionHeader(context, 'Notifications & Alerts', Icons.notifications_none_outlined),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.notifications_active_outlined),
                  title: const Text('Push Notifications'),
                  subtitle: const Text('Receive announcements and status updates'),
                  value: _pushNotifications,
                  onChanged: (val) => setState(() => _pushNotifications = val),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  secondary: const Icon(Icons.alarm),
                  title: const Text('Daily Check-in Reminder'),
                  subtitle: const Text('Notify 15 minutes before shift start time'),
                  value: _dailyReminders,
                  onChanged: (val) => setState(() => _dailyReminders = val),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Application Preferences
          _buildSectionHeader(context, 'App Preferences & Sync', Icons.tune_outlined),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.cloud_sync_outlined),
                  title: const Text('Auto-Sync Offline Scans'),
                  subtitle: const Text('Automatically upload pending attendance records when online'),
                  value: _autoSyncOffline,
                  onChanged: (val) => setState(() => _autoSyncOffline = val),
                ),
                const Divider(height: 1),
                const ListTile(
                  leading: Icon(Icons.gps_fixed),
                  title: Text('Geofence Distance Tolerance'),
                  subtitle: Text('500 meters from registered headquarters'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // About & Version Info
          _buildSectionHeader(context, 'About & Information', Icons.info_outline),
          Card(
            child: Column(
              children: [
                const ListTile(
                  leading: Icon(Icons.apps),
                  title: Text('Application Version'),
                  subtitle: Text('v1.0.0 (Build 1) Enterprise Edition'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.description_outlined),
                  title: const Text('Terms of Service'),
                  trailing: const Icon(Icons.open_in_new, size: 18),
                  onTap: () => _showTermsModal(context),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.privacy_tip_outlined),
                  title: const Text('Privacy Policy'),
                  trailing: const Icon(Icons.open_in_new, size: 18),
                  onTap: () => _showPrivacyModal(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Sign Out Button
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              onPressed: () => _confirmSignOut(context),
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Sign Out'),
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ],
      ),
    );
  }

  void _showLanguagePicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select Language',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ...supportedLanguages.map((lang) {
              return ListTile(
                leading: Text(lang.flag, style: const TextStyle(fontSize: 24)),
                title: Text(lang.name),
                onTap: () {
                  ref.read(languageProvider.notifier).setLanguage(lang);
                  Navigator.pop(ctx);
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  void _showAutoLockPicker(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Auto-Lock Inactivity Timeout'),
        children: ['1 minute', '5 minutes', '15 minutes', 'Never'].map((option) {
          return SimpleDialogOption(
            onPressed: () {
              setState(() => _autoLockTimeout = option);
              Navigator.pop(ctx);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(option),
            ),
          );
        }).toList(),
      ),
    );
  }

  void _sendPasswordReset(BuildContext context, String? email) async {
    if (email == null || email.isEmpty) return;
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password reset link sent to your email'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (err) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err.toString()), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showTermsModal(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Terms of Service'),
        content: const SingleChildScrollView(
          child: Text(
            'Chez Le Pointage is an enterprise attendance verification system. By using this application, you agree to allow geolocation verification during attendance clock-in events to confirm presence within designated office parameters.',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  void _showPrivacyModal(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Privacy Policy'),
        content: const SingleChildScrollView(
          child: Text(
            'Your location data is only accessed during active QR scanning and attendance registration events. Geolocation is used strictly for distance verification against official office coordinates and is stored securely in compliance with privacy regulations.',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  void _confirmSignOut(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out of your account?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              await FirebaseAuth.instance.signOut();
            },
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }
}
