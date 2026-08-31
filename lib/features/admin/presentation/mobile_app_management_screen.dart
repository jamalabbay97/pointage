import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/company_settings.dart';
import '../../../core/services/app_translations.dart';
import '../../../core/widgets/web_layout.dart';

class MobileAppManagementScreen extends ConsumerStatefulWidget {
  const MobileAppManagementScreen({super.key});

  @override
  ConsumerState<MobileAppManagementScreen> createState() =>
      _MobileAppManagementScreenState();
}

class _MobileAppManagementScreenState
    extends ConsumerState<MobileAppManagementScreen> {
  final _db = FirebaseFirestore.instance;
  bool _loading = true;
  bool _saving = false;

  late TextEditingController _mobileAppUrlController;
  late TextEditingController _mobileAppVersionController;
  late TextEditingController _mobileAppNotesController;

  bool _mobileAppEnabled = true;

  @override
  void initState() {
    super.initState();
    _mobileAppUrlController = TextEditingController();
    _mobileAppVersionController = TextEditingController();
    _mobileAppNotesController = TextEditingController();
    _loadSettings();
  }

  @override
  void dispose() {
    _mobileAppUrlController.dispose();
    _mobileAppVersionController.dispose();
    _mobileAppNotesController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    setState(() => _loading = true);
    try {
      final doc = await _db.collection('settings').doc('company').get();
      CompanySettings settings = CompanySettings.defaultSettings;
      if (doc.exists && doc.data() != null) {
        settings = CompanySettings.fromJson(doc.data()!);
      }
      _mobileAppUrlController.text = settings.mobileAppUrl;
      _mobileAppVersionController.text = settings.mobileAppVersion;
      _mobileAppNotesController.text = settings.mobileAppNotes;
      _mobileAppEnabled = settings.mobileAppEnabled;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${ref.tr('errorLoadingSettings')}: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveSettings() async {
    setState(() => _saving = true);
    try {
      // Load current settings to avoid overwriting unrelated fields
      final doc = await _db.collection('settings').doc('company').get();
      CompanySettings current = CompanySettings.defaultSettings;
      if (doc.exists && doc.data() != null) {
        current = CompanySettings.fromJson(doc.data()!);
      }

      final updated = CompanySettings(
        latitude: current.latitude,
        longitude: current.longitude,
        radiusMeters: current.radiusMeters,
        qrSecret: current.qrSecret,
        qrRotateIntervalSeconds: current.qrRotateIntervalSeconds,
        companyName: current.companyName,
        allowRemoteClockIn: current.allowRemoteClockIn,
        adminApiBaseUrl: current.adminApiBaseUrl,
        mobileAppUrl: _mobileAppUrlController.text.trim(),
        mobileAppVersion: _mobileAppVersionController.text.trim(),
        mobileAppNotes: _mobileAppNotesController.text.trim(),
        mobileAppEnabled: _mobileAppEnabled,
      );
      await _db.collection('settings').doc('company').set(updated.toJson());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ref.tr('settingsSaved')),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${ref.tr('errorSavingSettings')}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(ref.tr('mobileAppManagement')),
      ),
      body: WebLayout(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.phone_android,
                                  color: Colors.teal,
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  ref.tr('mobileAppManagement'),
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              ref.tr('mobileAppManagementDesc'),
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 16),
                            SwitchListTile(
                              title: Text(ref.tr('mobileAppEnabled')),
                              value: _mobileAppEnabled,
                              onChanged: (val) =>
                                  setState(() => _mobileAppEnabled = val),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _mobileAppUrlController,
                              keyboardType: TextInputType.url,
                              decoration: InputDecoration(
                                labelText: ref.tr('mobileAppUrl'),
                                prefixIcon:
                                    const Icon(Icons.download_for_offline),
                                hintText: ref.tr('mobileAppUrlHint'),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _mobileAppVersionController,
                              decoration: InputDecoration(
                                labelText: ref.tr('mobileAppVersion'),
                                prefixIcon: const Icon(Icons.verified),
                                hintText: 'e.g. v1.0.0',
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _mobileAppNotesController,
                              maxLines: 2,
                              decoration: InputDecoration(
                                labelText: ref.tr('mobileAppNotes'),
                                prefixIcon: const Icon(Icons.notes),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                if (_mobileAppUrlController.text
                                    .trim()
                                    .isNotEmpty)
                                  OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.redAccent,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _mobileAppUrlController.clear();
                                        _mobileAppNotesController.clear();
                                        _mobileAppVersionController.text =
                                            'v1.0.0';
                                        _mobileAppEnabled = false;
                                      });
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            ref.tr('confirmDeleteMobileApp'),
                                          ),
                                        ),
                                      );
                                    },
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      size: 18,
                                    ),
                                    label: Text(ref.tr('deleteMobileApp')),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _saving ? null : _saveSettings,
                        icon: _saving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.save_rounded),
                        label: Text(
                          _saving
                              ? ref.tr('saving')
                              : ref.tr('saveConfiguration'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
