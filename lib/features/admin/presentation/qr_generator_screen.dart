import 'dart:async';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:uuid/uuid.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/company_settings.dart';
import '../../../core/services/app_translations.dart';
import '../../../core/widgets/web_layout.dart';

class QrGeneratorScreen extends ConsumerStatefulWidget {
  const QrGeneratorScreen({super.key});

  @override
  ConsumerState<QrGeneratorScreen> createState() => _QrGeneratorScreenState();
}

class _QrGeneratorScreenState extends ConsumerState<QrGeneratorScreen> {
  CompanySettings _settings = CompanySettings.defaultSettings;
  Timer? _timer;
  int _secondsLeft = 15;
  String _rawPayload = '';
  DateTime _expiresAt = DateTime.now().add(const Duration(seconds: 15));
  bool _isFullscreen = false;

  @override
  void initState() {
    super.initState();
    _fetchSettingsAndStart();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _fetchSettingsAndStart() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('settings')
          .doc('company')
          .get();
      if (doc.exists && doc.data() != null) {
        _settings = CompanySettings.fromJson(doc.data()!);
      }
    } catch (_) {}
    _rotateQR();
    _startTimer();
  }

  void _rotateQR() {
    final now = DateTime.now().toUtc();
    final interval = _settings.qrRotateIntervalSeconds;
    _expiresAt = now.add(Duration(seconds: interval));
    final nonce = const Uuid().v4();
    final dateStr = DateFormat('yyyy-MM-dd').format(now);
    final expiresStr = _expiresAt.toIso8601String();

    final message = '$nonce|$dateStr|$expiresStr';
    final hmac = Hmac(sha256, utf8.encode(_settings.qrSecret));
    final signature = hmac.convert(utf8.encode(message)).toString();

    final payloadMap = {
      'nonce': nonce,
      'date': dateStr,
      'expiresAt': expiresStr,
      'signature': signature,
    };

    setState(() {
      _rawPayload = jsonEncode(payloadMap);
      _secondsLeft = interval;
    });
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsLeft <= 1) {
        _rotateQR();
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isFullscreen) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Stack(
            children: [
              Positioned(
                top: 16,
                right: 16,
                child: IconButton(
                  icon: const Icon(
                    Icons.fullscreen_exit,
                    color: Colors.white,
                    size: 32,
                  ),
                  onPressed: _exitFullscreen,
                ),
              ),
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _settings.companyName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      ref.tr('scanToRegister'),
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 18),
                    ),
                    const SizedBox(height: 32),
                    _buildQrCard(size: 280),
                    const SizedBox(height: 24),
                    _buildCountdownTimer(),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(ref.tr('dynamicQrGenerator')),
        actions: [
          IconButton(
            icon: const Icon(Icons.fullscreen),
            tooltip: ref.tr('presenterMode'),
            onPressed: _enterFullscreen,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: ref.tr('rotateNow'),
            onPressed: _rotateQR,
          ),
        ],
      ),
      body: WebLayout(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Text(
                        _settings.companyName,
                        style:
                            Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        ref.tr('dynamicHmacDesc'),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey.shade600,
                            ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      _buildQrCard(size: 220),
                      const SizedBox(height: 24),
                      _buildCountdownTimer(),
                      const SizedBox(height: 16),
                      FilledButton.tonalIcon(
                        onPressed: _rotateQR,
                        icon: const Icon(Icons.sync_rounded),
                        label: Text(ref.tr('forceRotation')),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.security,
                            size: 20,
                            color: Colors.blue,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            ref.tr('securityParameters'),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      _buildParamRow(
                        ref.tr('rotationInterval'),
                        '${_settings.qrRotateIntervalSeconds} ${ref.tr('seconds')}',
                      ),
                      _buildParamRow(
                        ref.tr('geofenceRadiusLabel'),
                        '${_settings.radiusMeters.toInt()} ${ref.tr('radiusMeters')}',
                      ),
                      _buildParamRow(
                        ref.tr('currentUtcTime'),
                        DateFormat('HH:mm:ss UTC')
                            .format(DateTime.now().toUtc()),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        ref.tr('signedPayload'),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _rawPayload,
                          style: const TextStyle(
                            fontSize: 11,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildParamRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade700)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildCountdownTimer() {
    final progress = _secondsLeft / _settings.qrRotateIntervalSeconds;
    return Column(
      children: [
        SizedBox(
          width: 140,
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor:
                Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
            color: Theme.of(context).colorScheme.primary,
            borderRadius: BorderRadius.circular(8),
            minHeight: 8,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '${ref.tr('rotatesIn')} $_secondsLeft ${ref.tr('seconds')}',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ],
    );
  }

  Widget _buildQrCard({required double size}) {
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            spreadRadius: 2,
          ),
        ],
      ),
      child: _rawPayload.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : QrImageView(
              data: _rawPayload,
              version: QrVersions.auto,
              size: size,
              gapless: false,
            ),
    );
  }

  void _enterFullscreen() async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(FirebaseAuth.instance.currentUser?.uid)
          .get();
      final pin = userDoc.data()?['kioskPin'] as String?;
      if (pin == null || pin.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(ref.tr('setPinFirst')),
            ),
          );
        }
        return;
      }
      setState(() => _isFullscreen = true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${ref.tr('errorCheckingPin')}: $e')),
        );
      }
    }
  }

  void _exitFullscreen() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(ref.tr('enterPinToExit')),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          obscureText: true,
          decoration: InputDecoration(labelText: ref.tr('presenterPin')),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(ref.tr('cancel')),
          ),
          FilledButton(
            onPressed: () async {
              try {
                final userDoc = await FirebaseFirestore.instance
                    .collection('users')
                    .doc(FirebaseAuth.instance.currentUser?.uid)
                    .get();
                final pin = userDoc.data()?['kioskPin'] as String?;

                if (pin != null && pin == controller.text.trim()) {
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (mounted) setState(() => _isFullscreen = false);
                } else {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(content: Text(ref.tr('incorrectPin'))),
                    );
                  }
                }
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(
                      content: Text('${ref.tr('verificationError')}: $e'),
                    ),
                  );
                }
              }
            },
            child: Text(ref.tr('verify')),
          ),
        ],
      ),
    );
  }
}
