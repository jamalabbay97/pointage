import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
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

  Future<void> _processQR(String? code) async {
    if (handled) return;
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
      final userRole =
          (userDoc.data()?['role'] as String? ?? '').trim().toLowerCase();
      if (userRole == 'admin') {
        throw StateError(
          'Administrators cannot check in or check out. Use the admin reports dashboard to manage employee attendance.',
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
      await service.register(
        employeeId: user.uid,
        employeeName:
            user.displayName ?? (user.email?.split('@').first ?? 'Employee'),
        settings: settings,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 10),
                Expanded(child: Text('Attendance Successfully Registered!')),
              ],
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
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
                  _processQR(
                    jsonEncode({
                      'nonce': 'sim_nonce_123',
                      'date': DateTime.now().toIso8601String().substring(0, 10),
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
                },
              ),
          ],
        ),
        body: Stack(
          children: [
            MobileScanner(
              onDetect: (capture) {
                final List<Barcode> barcodes = capture.barcodes;
                if (barcodes.isNotEmpty) {
                  _processQR(barcodes.first.rawValue);
                }
              },
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
