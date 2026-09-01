import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:url_launcher/url_launcher.dart';

import '../../../core/services/app_translations.dart';
import '../../../core/services/language_provider.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/widgets/mobile_app_download_dialog.dart';
import '../../../core/widgets/web_layout.dart';
import '../../attendance/domain/offline_sync_service.dart';
import '../../auth/domain/auth_provider.dart';

import '../../profile/presentation/profile_screen.dart';
import '../../../core/models/user_model.dart';
import '../data/settings_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  // Empty state, all logic moved to Riverpod

  @override
  Widget build(BuildContext context) {
    final currentThemeMode = ref.watch(themeModeProvider);
    final currentLang = ref.watch(languageProvider);
    final userModel = ref.watch(currentUserModelProvider).valueOrNull;
    final firebaseUser = FirebaseAuth.instance.currentUser;
    final userSettings = ref.watch(userSettingsProvider).valueOrNull;

    final avatarImage = ProfileScreen.getProfileImageProvider(
      userModel?.photoUrl ?? firebaseUser?.photoURL,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(ref.tr('settingsCenter')),
      ),
      body: WebLayout(
        child: ListView(
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
                      backgroundColor:
                          Theme.of(context).colorScheme.primaryContainer,
                      backgroundImage: avatarImage,
                      child: avatarImage == null
                          ? Text(
                              (userModel?.displayName.isNotEmpty == true)
                                  ? userModel!.displayName[0].toUpperCase()
                                  : 'U',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            userModel?.displayName ??
                                firebaseUser?.displayName ??
                                ref.tr('employee'),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            firebaseUser?.email ?? 'N/A',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Chip(
                            visualDensity: VisualDensity.compact,
                            label: Text(
                              (userModel?.role ?? 'employee').toUpperCase(),
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            backgroundColor: Theme.of(context)
                                .colorScheme
                                .primary
                                .withValues(alpha: 0.1),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Theme & Appearance
            _buildSectionHeader(
              context,
              ref.tr('appearanceTheme'),
              Icons.palette_outlined,
            ),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ref.tr('themeMode'),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    SegmentedButton<ThemeMode>(
                      segments: [
                        ButtonSegment(
                          value: ThemeMode.light,
                          label: Text(ref.tr('light')),
                          icon: const Icon(Icons.wb_sunny_outlined),
                        ),
                        ButtonSegment(
                          value: ThemeMode.dark,
                          label: Text(ref.tr('dark')),
                          icon: const Icon(Icons.nightlight_round),
                        ),
                        ButtonSegment(
                          value: ThemeMode.system,
                          label: Text(ref.tr('system')),
                          icon: const Icon(Icons.settings_suggest_outlined),
                        ),
                      ],
                      selected: {currentThemeMode},
                      onSelectionChanged: (Set<ThemeMode> newSelection) {
                        ref
                            .read(themeModeProvider.notifier)
                            .setThemeMode(newSelection.first);
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Language & Localization
            _buildSectionHeader(
              context,
              ref.tr('langRegion'),
              Icons.language_outlined,
            ),
            Card(
              child: ListTile(
                leading: Text(
                  currentLang.flag,
                  style: const TextStyle(fontSize: 24),
                ),
                title: Text(ref.tr('appLang')),
                subtitle: Text(currentLang.name),
                trailing: const Icon(Icons.arrow_drop_down),
                onTap: () => _showLanguagePicker(context),
              ),
            ),
            const SizedBox(height: 20),

            // Account & Security Settings
            _buildSectionHeader(
              context,
              ref.tr('accountSecurity'),
              Icons.lock_outline,
            ),
            Card(
              child: Column(
                children: [
                  SwitchListTile(
                    secondary: const Icon(Icons.fingerprint),
                    title: Text(ref.tr('biometricAuth')),
                    subtitle: Text(ref.tr('biometricSub')),
                    value: userSettings?.biometricEnabled ?? true,
                    onChanged: (val) {
                      ref
                          .read(userSettingsProvider.notifier)
                          .updateBiometric(val);
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.timer_outlined),
                    title: Text(ref.tr('autoLock')),
                    subtitle: Text(
                      _localizedAutoLock(
                        userSettings?.autoLockTimeout ?? '5 minutes',
                      ),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _showAutoLockPicker(context),
                  ),
                  if (userModel?.isAdminOrManager == true) ...[
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.password_outlined),
                      title: Text(ref.tr('presenterPin')),
                      subtitle: Text(
                        userModel?.kioskPin != null
                            ? ref.tr('pinIsSet')
                            : ref.tr('pinNotSet'),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _showSetPinDialog(context, userModel!),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Notification Settings
            _buildSectionHeader(
              context,
              ref.tr('notificationsAlerts'),
              Icons.notifications_none_outlined,
            ),
            Card(
              child: Column(
                children: [
                  SwitchListTile(
                    secondary: const Icon(Icons.notifications_active_outlined),
                    title: Text(ref.tr('pushNotifications')),
                    subtitle: Text(ref.tr('pushNotifSub')),
                    value: userSettings?.pushNotifications ?? true,
                    onChanged: (val) {
                      ref.read(userSettingsProvider.notifier).updatePush(val);
                    },
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    secondary: const Icon(Icons.alarm),
                    title: Text(ref.tr('dailyReminder')),
                    subtitle: Text(ref.tr('dailyReminderSub')),
                    value: userSettings?.dailyReminders ?? true,
                    onChanged: (val) {
                      ref.read(userSettingsProvider.notifier).updateDaily(val);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Application Preferences
            _buildSectionHeader(
              context,
              ref.tr('appPrefsSync'),
              Icons.tune_outlined,
            ),
            Card(
              child: Column(
                children: [
                  SwitchListTile(
                    secondary: const Icon(Icons.cloud_sync_outlined),
                    title: Text(ref.tr('autoSync')),
                    subtitle: Text(ref.tr('autoSyncSub')),
                    value: userSettings?.autoSyncOffline ?? true,
                    onChanged: (val) {
                      ref.read(userSettingsProvider.notifier).updateSync(val);
                    },
                  ),
                  const Divider(height: 1),
                  Consumer(
                    builder: (context, ref, _) {
                      final pendingCountAsync =
                          ref.watch(pendingSyncCountProvider);
                      final pendingCount = pendingCountAsync.valueOrNull ?? 0;
                      return ListTile(
                        leading: const Icon(Icons.sync_rounded),
                        title: Text(ref.tr('syncNow')),
                        subtitle: Text(
                          pendingCount > 0
                              ? '$pendingCount ${ref.tr('offlinePendingRecords')}'
                              : ref.tr('noPendingRecords'),
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () async {
                          final synced = await ref
                              .read(offlineSyncServiceProvider)
                              .syncPendingRecords();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  synced > 0
                                      ? ref
                                          .tr('syncSuccessMsg')
                                          .replaceAll('{count}', '$synced')
                                      : ref.tr('noNetworkToSync'),
                                ),
                              ),
                            );
                          }
                        },
                      );
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.gps_fixed),
                    title: Text(ref.tr('geofenceTol')),
                    subtitle: Text(
                      '${userModel?.assignedLocationRadius?.toInt() ?? 500} ${ref.tr('metersFromHq')}',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // About & Version Info
            _buildSectionHeader(
              context,
              ref.tr('aboutInfo'),
              Icons.info_outline,
            ),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.phone_android),
                    title: Text(ref.tr('downloadMobileApp')),
                    subtitle: Text(ref.tr('mobileAppDownloadSub')),
                    trailing: const Icon(Icons.qr_code_2, size: 22),
                    onTap: () => MobileAppDownloadDialog.show(context),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.apps),
                    title: Text(ref.tr('appVersion')),
                    subtitle: Text(ref.tr('versionSub')),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.description_outlined),
                    title: Text(ref.tr('terms')),
                    trailing: const Icon(Icons.open_in_new, size: 18),
                    onTap: () => _showTermsModal(context),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.privacy_tip_outlined),
                    title: Text(ref.tr('privacy')),
                    trailing: const Icon(Icons.open_in_new, size: 18),
                    onTap: () => _showPrivacyModal(context),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.email_outlined),
                    title: Text(ref.tr('contactDeveloper')),
                    subtitle: const Text('jamal.abbay@gmail.com'),
                    trailing: const Icon(Icons.mail, size: 18),
                    onTap: () async {
                      final uri = Uri.parse(
                        'mailto:jamal.abbay@gmail.com?subject=App%20Pointage%20Feedback%20/%20Request',
                      );
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri);
                      } else if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content:
                                Text('Developer email: jamal.abbay@gmail.com'),
                          ),
                        );
                      }
                    },
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
                label: Text(ref.tr('signOut')),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(
    BuildContext context,
    String title,
    IconData icon,
  ) {
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
              ref.tr('selectLang'),
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
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

  /// Maps the stored English auto-lock value to a localized display label.
  String _localizedAutoLock(String storedValue) {
    switch (storedValue) {
      case '1 minute':
        return ref.tr('1minute');
      case '5 minutes':
        return ref.tr('5minutes');
      case '15 minutes':
        return ref.tr('15minutes');
      case 'Never':
        return ref.tr('never');
      default:
        return storedValue;
    }
  }

  void _showAutoLockPicker(BuildContext context) {
    final options = [
      {'val': '1 minute', 'label': ref.tr('1minute')},
      {'val': '5 minutes', 'label': ref.tr('5minutes')},
      {'val': '15 minutes', 'label': ref.tr('15minutes')},
      {'val': 'Never', 'label': ref.tr('never')},
    ];

    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(ref.tr('autoLock')),
        children: options.map((opt) {
          return SimpleDialogOption(
            onPressed: () {
              ref.read(userSettingsProvider.notifier).updateLock(opt['val']!);
              Navigator.pop(ctx);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(opt['label']!),
            ),
          );
        }).toList(),
      ),
    );
  }

  void _showSetPinDialog(BuildContext context, UserModel user) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ref.tr('setPresenterPin')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              ref.tr('pinHelpText'),
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              maxLength: 6,
              obscureText: true,
              decoration: InputDecoration(
                labelText: ref.tr('enterPinLength'),
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(ref.tr('cancel')),
          ),
          FilledButton(
            onPressed: () async {
              final pin = controller.text.trim();
              if (pin.length < 4 || pin.length > 6) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(ref.tr('pinLengthError'))),
                );
                return;
              }
              try {
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(user.uid)
                    .update({'kioskPin': pin});
                if (context.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(ref.tr('pinSaved')),
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${ref.tr('failedToSavePin')}: $e')),
                  );
                }
              }
            },
            child: Text(ref.tr('save')),
          ),
        ],
      ),
    );
  }

  void _showTermsModal(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ref.tr('terms')),
        content: SingleChildScrollView(
          child: Text(ref.tr('termsContent')),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(ref.tr('close')),
          ),
        ],
      ),
    );
  }

  void _showPrivacyModal(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ref.tr('privacy')),
        content: SingleChildScrollView(
          child: Text(ref.tr('privacyContent')),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(ref.tr('close')),
          ),
        ],
      ),
    );
  }

  void _confirmSignOut(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ref.tr('signOut')),
        content: Text(ref.tr('signOutConfirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(ref.tr('cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              const storage = FlutterSecureStorage();
              await storage.delete(key: 'email');
              await storage.delete(key: 'password');
              await FirebaseAuth.instance.signOut();
            },
            child: Text(ref.tr('signOut')),
          ),
        ],
      ),
    );
  }
}
