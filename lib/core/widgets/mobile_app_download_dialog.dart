import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/company_settings.dart';
import '../services/app_translations.dart';

class MobileAppDownloadDialog extends ConsumerWidget {
  const MobileAppDownloadDialog({super.key, this.customSettings});

  final CompanySettings? customSettings;

  static Future<void> show(
    BuildContext context, {
    CompanySettings? settings,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => MobileAppDownloadDialog(customSettings: settings),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (customSettings != null) {
      return _buildContent(context, ref, customSettings!);
    }

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('settings')
          .doc('company')
          .get(),
      builder: (context, snapshot) {
        CompanySettings settings = CompanySettings.defaultSettings;
        if (snapshot.hasData && snapshot.data?.data() != null) {
          settings = CompanySettings.fromJson(
            snapshot.data!.data() as Map<String, dynamic>,
          );
        }

        return _buildContent(context, ref, settings);
      },
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    CompanySettings settings,
  ) {
    final hasUrl = settings.mobileAppUrl.trim().isNotEmpty;
    final url = hasUrl
        ? settings.mobileAppUrl.trim()
        : 'https://pointage-app-cdb02.web.app';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.phone_android_rounded,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ref.tr('downloadMobileApp'),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${ref.tr('mobileAppVersion')}: ${settings.mobileAppVersion}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (!settings.mobileAppEnabled)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  ref.tr('mobileAppNotConfigured'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.orange, fontSize: 13),
                ),
              )
            else ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF2A2A2A) : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant,
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    QrImageView(
                      data: url,
                      version: QrVersions.auto,
                      size: 180,
                      backgroundColor: Colors.white,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      ref.tr('scanToDownloadApp'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (settings.mobileAppNotes.isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest
                        .withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ref.tr('mobileAppNotes'),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        settings.mobileAppNotes,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(ref.tr('close')),
        ),
        if (settings.mobileAppEnabled && hasUrl)
          FilledButton.icon(
            onPressed: () async {
              final uri = Uri.parse(url);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              } else if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Could not launch $url')),
                );
              }
            },
            icon: const Icon(Icons.download_rounded),
            label: Text(ref.tr('downloadApkBtn')),
          ),
      ],
    );
  }
}
