import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/config/company_settings.dart';
import '../../../core/services/app_translations.dart';
import '../../../core/services/security_services.dart';
import '../../attendance/domain/attendance_service.dart';
import '../../auth/domain/auth_provider.dart';

class QrScannerScreen extends ConsumerStatefulWidget {
  const QrScannerScreen({super.key});

  @override
  ConsumerState<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends ConsumerState<QrScannerScreen> {
  bool handled = false;
  bool processing = false;
  bool locationReady = false;
  bool checkingLocation = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureLocationReady());
  }

  Future<void> _ensureLocationReady() async {
    if (!mounted) return;
    setState(() => checkingLocation = true);

    var serviceEnabled = await Geolocator.isLocationServiceEnabled();
    var permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    final permissionGranted = permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;

    if (!serviceEnabled || !permissionGranted) {
      if (mounted) {
        setState(() {
          locationReady = false;
          checkingLocation = false;
        });
        await _showLocationRequiredDialog(
          serviceEnabled: serviceEnabled,
          permissionGranted: permissionGranted,
        );
      }

      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      permission = await Geolocator.checkPermission();
    }

    if (!mounted) return;
    setState(() {
      locationReady = serviceEnabled &&
          (permission == LocationPermission.always ||
              permission == LocationPermission.whileInUse);
      checkingLocation = false;
    });
  }

  Future<void> _showLocationRequiredDialog({
    required bool serviceEnabled,
    required bool permissionGranted,
  }) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.location_on),
        title: Text(ref.tr('enableGpsToScan')),
        content: Text(
          !serviceEnabled
              ? ref.tr('locationServicesDisabled')
              : !permissionGranted
                  ? ref.tr('locationPermissionRequired')
                  : ref.tr('locationPermissionRequired'),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              if (this.context.canPop()) {
                this.context.pop();
              }
            },
            child: Text(ref.tr('cancel')),
          ),
          FilledButton.icon(
            onPressed: () async {
              if (!serviceEnabled) {
                await Geolocator.openLocationSettings();
              } else {
                await Geolocator.openAppSettings();
              }
              if (context.mounted) context.pop();
            },
            icon: const Icon(Icons.settings),
            label: Text(ref.tr('openSettings')),
          ),
        ],
      ),
    );
  }

  Future<void> _processQR(String? code) async {
    if (handled || !locationReady) return;
    handled = true;
    if (code == null || code.isEmpty) {
      handled = false;
      return;
    }

    setState(() => processing = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw StateError('ERR:notAuthenticated');

      final db = FirebaseFirestore.instance;
      Map<String, dynamic>? userData;
      try {
        final userDoc = await db.collection('users').doc(user.uid).get();
        userData = userDoc.data();
      } catch (_) {
        final cachedModel = ref.read(currentUserModelProvider).valueOrNull;
        if (cachedModel != null) {
          userData = cachedModel.toJson();
        }
      }

      final userRole =
          (userData?['role'] as String? ?? '').trim().toLowerCase();
      final accountOwnerName = _accountOwnerName(userData, user);
      if (userRole == 'admin' || userRole == 'manager') {
        throw StateError(
          userRole == 'admin'
              ? 'ERR:adminCannotCheckIn'
              : 'ERR:managerCannotCheckIn',
        );
      }

      CompanySettings settings = CompanySettings.defaultSettings;
      try {
        final doc = await db.collection('settings').doc('company').get();
        if (doc.exists && doc.data() != null) {
          settings = CompanySettings.fromJson(doc.data()!);
        }
      } catch (_) {}

      if (code.trim().startsWith('{')) {
        final verifier = QrVerifier(settings.qrSecret);
        try {
          final isVerified = verifier.verify(code);
          if (!isVerified) {
            throw StateError('ERR:invalidQrCode');
          }
        } catch (e) {
          final msg = e.toString().replaceAll('StateError: ', '');
          if (msg.startsWith('ERR:')) throw StateError(msg);
          throw StateError('ERR:qrVerificationFailed');
        }
      }

      final service = AttendanceService(db);
      final result = await service.register(
        employeeId: user.uid,
        employeeName: accountOwnerName,
        settings: settings,
      );

      if (mounted) {
        final isOfflineMsg = result.message.contains('Offline');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  isOfflineMsg ? Icons.cloud_off_rounded : Icons.check_circle,
                  color: Colors.white,
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(_localizeMessage(result.message))),
              ],
            ),
            backgroundColor:
                isOfflineMsg ? Colors.orange.shade800 : Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/dashboard');
        }
      }
    } catch (e) {
      if (mounted) {
        final rawMsg = e
            .toString()
            .replaceAll('Exception: ', '')
            .replaceAll('StateError: ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_localizeMessage(rawMsg)),
            backgroundColor: Colors.redAccent,
            duration: const Duration(seconds: 4),
          ),
        );
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/dashboard');
        }
      }
      handled = false;
    } finally {
      if (mounted) setState(() => processing = false);
    }
  }

  /// Decodes a structured ERR:/SUCCESS: code (from AttendanceService) into
  /// a localized string for the current language. Falls back to the raw
  /// message if the code is not recognized.
  String _localizeMessage(String raw) {
    if (raw.startsWith('ERR:')) {
      final parts = raw.substring(4).split('|');
      final key = parts[0];
      switch (key) {
        case 'notInOfficePerimeter':
          // parts[1] = distance, parts[2] = allowed radius
          final dist = parts.length > 1 ? parts[1] : '?';
          final radius = parts.length > 2 ? parts[2] : '?';
          return '${ref.tr('notInOfficePerimeter')} (${dist}m, max ${radius}m)';
        default:
          final localized = ref.tr(key);
          return localized != key ? localized : raw;
      }
    }
    if (raw.startsWith('SUCCESS:')) {
      final parts = raw.substring(8).split('|');
      final type = parts[0];
      final time = parts.length > 1 ? parts[1] : '';
      if (type == 'checkIn') {
        return ref.tr('checkInSuccess').replaceAll('{time}', time);
      }
      if (type == 'checkOut') {
        return ref.tr('checkOutSuccess').replaceAll('{time}', time);
      }
      if (type == 'checkInOffline') {
        return ref.tr('checkInOfflineSuccess').replaceAll('{time}', time);
      }
      if (type == 'checkOutOffline') {
        return ref.tr('checkOutOfflineSuccess').replaceAll('{time}', time);
      }
    }
    return raw;
  }

  String _accountOwnerName(Map<String, dynamic>? userData, User user) {
    final profileName = (userData?['displayName'] as String? ?? '').trim();
    if (profileName.isNotEmpty) return profileName;

    final authName = user.displayName?.trim() ?? '';
    if (authName.isNotEmpty) return authName;

    final emailName = user.email?.split('@').first.trim() ?? '';
    if (emailName.isNotEmpty) return emailName;

    return 'Employee';
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text(ref.tr('scanQrCode')),
          actions: [
            if (kDebugMode &&
                (kIsWeb ||
                    defaultTargetPlatform == TargetPlatform.windows ||
                    defaultTargetPlatform == TargetPlatform.macOS))
              IconButton(
                icon: const Icon(Icons.bug_report),
                tooltip: 'Simulate QR Scan (Desktop/Web Test)',
                onPressed: () {
                  if (locationReady) {
                    _processQR(
                      jsonEncode({
                        'nonce': 'sim_nonce_123',
                        'date':
                            DateTime.now().toIso8601String().substring(0, 10),
                        'expiresAt': DateTime.now()
                            .add(const Duration(minutes: 5))
                            .toIso8601String(),
                        'signature':
                            QrVerifier(CompanySettings.defaultSettings.qrSecret)
                                .hmacSha256(
                          'sim_nonce_123|${DateTime.now().toIso8601String().substring(0, 10)}|${DateTime.now().add(const Duration(minutes: 5)).toIso8601String()}',
                        ),
                      }),
                    );
                  } else {
                    _ensureLocationReady();
                  }
                },
              ),
          ],
        ),
        body: Stack(
          children: [
            if (locationReady)
              MobileScanner(
                onDetect: (capture) {
                  final List<Barcode> barcodes = capture.barcodes;
                  if (barcodes.isNotEmpty) {
                    _processQR(barcodes.first.rawValue);
                  }
                },
              )
            else
              Container(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      ref.tr('locationPermissionRequired'),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
            Center(
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Theme.of(context).colorScheme.primary,
                    width: 4,
                  ),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: 0.3),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              bottom: 40,
              left: 24,
              right: 24,
              child: Card(
                color: Colors.black.withValues(alpha: 0.75),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.info_outline,
                        color: Colors.white,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        ref.tr('alignQrCodeFrame'),
                        style:
                            const TextStyle(color: Colors.white, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (!locationReady)
              Container(
                color: Colors.black.withValues(alpha: 0.78),
                child: Center(
                  child: Card(
                    margin: const EdgeInsets.all(24),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.location_off,
                            color: Theme.of(context).colorScheme.primary,
                            size: 48,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            ref.tr('gpsRequired'),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            ref.tr('locationPermissionRequired'),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 18),
                          FilledButton.icon(
                            onPressed:
                                checkingLocation ? null : _ensureLocationReady,
                            icon: checkingLocation
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.my_location),
                            label: Text(
                              checkingLocation
                                  ? ref.tr('loading')
                                  : ref.tr('enableGps'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            if (processing)
              Container(
                color: Colors.black.withValues(alpha: 0.7),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(color: Colors.white),
                      const SizedBox(height: 20),
                      Text(
                        ref.tr('verifyingGeofence'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      );
}
