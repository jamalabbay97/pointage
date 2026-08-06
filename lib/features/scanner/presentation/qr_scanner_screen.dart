import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/config/company_settings.dart';
import '../../../core/services/security_services.dart';
import '../../attendance/domain/attendance_service.dart';

class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
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
        title: const Text('Enable GPS to scan'),
        content: Text(
          !serviceEnabled
              ? 'Location Services are turned off. Please enable GPS before scanning your QR code for attendance.'
              : !permissionGranted
                  ? 'Location permission is required before scanning your QR code for attendance.'
                  : 'GPS must be enabled before scanning your QR code for attendance.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              if (this.context.canPop()) {
                this.context.pop();
              }
            },
            child: const Text('Cancel'),
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
            label: const Text('Open settings'),
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
      if (user == null) throw StateError('Not authenticated');

      final db = FirebaseFirestore.instance;
      final userDoc = await db.collection('users').doc(user.uid).get();
      final userData = userDoc.data();
      final userRole =
          (userData?['role'] as String? ?? '').trim().toLowerCase();
      final accountOwnerName = _accountOwnerName(userData, user);
      if (userRole == 'admin' || userRole == 'manager') {
        throw StateError(
          userRole == 'admin'
              ? 'Administrators cannot check in or check out. Use the admin reports dashboard to manage employee attendance.'
              : 'Managers are supervisors and cannot check in or check out.',
        );
      }

      // 1. Fetch live CompanySettings from Firestore
      CompanySettings settings = CompanySettings.defaultSettings;
      try {
        final doc = await db.collection('settings').doc('company').get();
        if (doc.exists && doc.data() != null) {
          settings = CompanySettings.fromJson(doc.data()!);
        }
      } catch (_) {}

      // 2. Validate HMAC Signature if dynamic JSON QR
      if (code.trim().startsWith('{')) {
        final verifier = QrVerifier(settings.qrSecret);
        try {
          final isVerified = verifier.verify(code);
          if (!isVerified) {
            throw StateError('Invalid or expired QR code signature.');
          }
        } catch (e) {
          throw StateError(
            'QR Verification failed: ${e.toString().replaceAll('StateError: ', '')}',
          );
        }
      }

      // 3. Register Attendance
      final service = AttendanceService(db);
      final result = await service.register(
        employeeId: user.uid,
        employeeName: accountOwnerName,
        settings: settings,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 10),
                Expanded(child: Text(result.message)),
              ],
            ),
            backgroundColor: Colors.green,
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e
                  .toString()
                  .replaceAll('Exception: ', '')
                  .replaceAll('StateError: ', ''),
            ),
            backgroundColor: Colors.redAccent,
            duration: const Duration(seconds: 4),
          ),
        );
      }
      handled = false;
    } finally {
      if (mounted) setState(() => processing = false);
    }
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
          title: const Text('Scan QR Code'),
          actions: [
            if (kIsWeb ||
                defaultTargetPlatform == TargetPlatform.windows ||
                defaultTargetPlatform == TargetPlatform.macOS)
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
                child: const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'GPS is required before scanning. Enable Location Services to continue.',
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
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.info_outline, color: Colors.white, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Align QR Code within frame to verify',
                        style: TextStyle(color: Colors.white, fontSize: 13),
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
                          const Text(
                            'GPS Required',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Enable Location Services to unlock QR scanning and record accurate attendance.',
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
                              checkingLocation ? 'Checking...' : 'Enable GPS',
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
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: Colors.white),
                      SizedBox(height: 20),
                      Text(
                        'Verifying Geofence & Registering...',
                        style: TextStyle(
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
