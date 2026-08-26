import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:local_auth/local_auth.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/services/app_translations.dart';
import '../../../core/utils/async_timeout.dart';
import '../domain/user_sync_service.dart';

enum _RecoveryStep { input, verifyOtpAndReset }

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final email = TextEditingController();
  final password = TextEditingController();
  bool remember = true;
  bool loading = false;
  bool obscurePassword = true;
  final _storage = const FlutterSecureStorage();
  final _auth = LocalAuthentication();

  @override
  void initState() {
    super.initState();
    _checkBiometrics();
  }

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> _checkBiometrics() async {
    if (kIsWeb) return;
    try {
      final canAuthenticate =
          await _auth.canCheckBiometrics || await _auth.isDeviceSupported();
      if (!canAuthenticate) return;

      final savedEmail = await _storage.read(key: 'email');
      final savedPassword = await _storage.read(key: 'password');

      if (savedEmail != null && savedPassword != null) {
        final didAuthenticate = await _auth.authenticate(
          localizedReason: ref.tr('biometricReason'),
          options: const AuthenticationOptions(biometricOnly: true),
        );
        if (didAuthenticate) {
          email.text = savedEmail;
          password.text = savedPassword;
          await _login();
        }
      }
    } on PlatformException catch (e) {
      debugPrint('Biometrics error: $e');
    }
  }

  Future<void> _persistCredentials() async {
    try {
      if (remember) {
        await withTimeout(
          Future.wait([
            _storage.write(key: 'email', value: email.text.trim()),
            _storage.write(key: 'password', value: password.text),
          ]),
          duration: const Duration(seconds: 5),
          label: 'Saving credentials timed out',
        );
      } else {
        await withTimeout(
          Future.wait([
            _storage.delete(key: 'email'),
            _storage.delete(key: 'password'),
          ]),
          duration: const Duration(seconds: 5),
          label: 'Clearing credentials timed out',
        );
      }
    } catch (_) {
      // Non-fatal: login should still succeed without saved credentials.
    }
  }

  Future<void> _login() async {
    if (email.text.trim().isEmpty || password.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ref.tr('fillAllFields'))),
      );
      return;
    }

    setState(() => loading = true);
    try {
      final cred = await withTimeout(
        FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email.text.trim(),
          password: password.text,
        ),
        duration: const Duration(seconds: 30),
        label: 'Sign-in timed out. Check your network connection.',
      );

      final user = cred.user;
      if (user != null) {
        final syncResult = await syncUserAfterLogin(user);
        if (syncResult == UserSyncResult.disabled) {
          await FirebaseAuth.instance.signOut();
          if (!mounted) return;
          await showDialog<void>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Row(
                children: [
                  const Icon(Icons.block, color: Colors.red),
                  const SizedBox(width: 8),
                  Text(ref.tr('accountDisabled')),
                ],
              ),
              content: Text(
                ref.tr('accountDisabledDesc'),
              ),
              actions: [
                FilledButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(ref.tr('ok')),
                ),
              ],
            ),
          );
          return;
        }

        if (syncResult == UserSyncResult.failed && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                ref.tr('syncDelayed'),
              ),
            ),
          );
        }
      }

      await _persistCredentials();

      if (mounted) context.go('/dashboard');
    } on TimeoutException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message ?? ref.tr('connectionTimedOut')),
          backgroundColor: Colors.redAccent,
        ),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message ?? ref.tr('loginFailed')),
          backgroundColor: Colors.redAccent,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _showForgotPasswordDialog() async {
    final recoverController = TextEditingController(text: email.text.trim());
    final otpController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();

    _RecoveryStep currentStep = _RecoveryStep.input;
    bool isSubmitting = false;
    bool obscurePassword = true;
    bool obscureConfirmPassword = true;
    String? dialogError;
    String? recoveryToken;
    String inputPhone = '';

    await showDialog<void>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            title: Row(
              children: [
                Icon(
                  currentStep == _RecoveryStep.verifyOtpAndReset
                      ? Icons.lock_reset_rounded
                      : Icons.lock_outline,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  currentStep == _RecoveryStep.verifyOtpAndReset
                      ? ref.tr('setNewPassword')
                      : ref.tr('recoverPassword'),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (currentStep == _RecoveryStep.input) ...[
                    Text(
                      ref.tr('enterEmailOrPhone'),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: recoverController,
                      enabled: !isSubmitting,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: ref.tr('emailOrPhoneLabel'),
                        hintText: ref.tr('phoneNumberHint'),
                        prefixIcon: const Icon(Icons.contact_mail_outlined),
                      ),
                    ),
                  ] else if (currentStep ==
                      _RecoveryStep.verifyOtpAndReset) ...[
                    Text(
                      ref.tr('enterOtp').replaceAll('{phone}', inputPhone),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: otpController,
                      enabled: !isSubmitting,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      decoration: InputDecoration(
                        labelText: ref.tr('otpCode'),
                        prefixIcon: const Icon(Icons.pin_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: newPasswordController,
                      obscureText: obscurePassword,
                      enabled: !isSubmitting,
                      decoration: InputDecoration(
                        labelText: ref.tr('newPassword'),
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscurePassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                          onPressed: () => setDialogState(
                            () => obscurePassword = !obscurePassword,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: confirmPasswordController,
                      obscureText: obscureConfirmPassword,
                      enabled: !isSubmitting,
                      decoration: InputDecoration(
                        labelText: ref.tr('confirmNewPassword'),
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscureConfirmPassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                          onPressed: () => setDialogState(
                            () => obscureConfirmPassword =
                                !obscureConfirmPassword,
                          ),
                        ),
                      ),
                    ),
                  ],
                  if (dialogError != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      dialogError!,
                      style: const TextStyle(color: Colors.red, fontSize: 13),
                    ),
                  ],
                  if (isSubmitting) ...[
                    const SizedBox(height: 16),
                    const Center(child: CircularProgressIndicator()),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSubmitting ? null : () => Navigator.pop(dialogCtx),
                child: Text(ref.tr('cancel')),
              ),
              FilledButton(
                onPressed: isSubmitting
                    ? null
                    : () async {
                        if (currentStep == _RecoveryStep.input) {
                          final input = recoverController.text.trim();
                          if (input.isEmpty) {
                            setDialogState(() {
                              dialogError = ref.tr('invalidEmailOrPhone');
                            });
                            return;
                          }

                          setDialogState(() {
                            isSubmitting = true;
                            dialogError = null;
                          });

                          final isEmail =
                              input.contains('@') && input.contains('.');

                          if (isEmail) {
                            try {
                              await withTimeout(
                                FirebaseAuth.instance.sendPasswordResetEmail(
                                  email: input,
                                ),
                                duration: const Duration(seconds: 20),
                                label: 'Password reset request timed out',
                              );
                              if (dialogCtx.mounted && mounted) {
                                Navigator.pop(dialogCtx);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      ref
                                          .tr('passwordResetEmailSent')
                                          .replaceAll('{email}', input),
                                    ),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              }
                            } catch (err) {
                              setDialogState(() {
                                isSubmitting = false;
                                dialogError = err.toString();
                              });
                            }
                          } else {
                            inputPhone = input;
                            try {
                              final baseUrl =
                                  await AppConfig.resolveAdminApiBaseUrl(
                                FirebaseFirestore.instance,
                              );
                              final effectiveBaseUrl = baseUrl.isNotEmpty
                                  ? baseUrl
                                  : 'https://pointage-api-zrot.onrender.com';
                              final uri = Uri.parse(
                                '$effectiveBaseUrl/users/request-phone-otp',
                              );
                              final resp = await http.post(
                                uri,
                                headers: {'Content-Type': 'application/json'},
                                body: jsonEncode({'phoneNumber': input}),
                              );

                              if (resp.statusCode == 200 ||
                                  resp.statusCode == 429) {
                                final data = jsonDecode(resp.body);
                                if (resp.statusCode == 429) {
                                  setDialogState(() {
                                    isSubmitting = false;
                                    dialogError =
                                        data['message'] ?? 'Too many attempts';
                                  });
                                  return;
                                }

                                recoveryToken = data['recoveryToken'];
                                final debugOtp = data['debugOtp'];
                                setDialogState(() {
                                  currentStep = _RecoveryStep.verifyOtpAndReset;
                                  isSubmitting = false;
                                  dialogError = null;
                                  if (debugOtp != null) {
                                    otpController.text = debugOtp.toString();
                                  }
                                });
                              } else if (resp.statusCode == 404) {
                                setDialogState(() {
                                  isSubmitting = false;
                                  dialogError =
                                      'Backend recovery endpoint not found (404).\nPlease deploy the latest backend code or start local backend.';
                                });
                              } else {
                                setDialogState(() {
                                  isSubmitting = false;
                                  dialogError =
                                      'Backend server unavailable (${resp.statusCode}).';
                                });
                              }
                            } catch (err) {
                              setDialogState(() {
                                isSubmitting = false;
                                final errStr = err.toString();
                                if (errStr.contains('Connection refused') ||
                                    errStr.contains('SocketException')) {
                                  dialogError =
                                      'Unable to connect to recovery server.\nMake sure backend server is running and Admin API Base URL is set in System Settings.';
                                } else {
                                  dialogError =
                                      'Unable to connect to recovery server: $err';
                                }
                              });
                            }
                          }
                        } else if (currentStep ==
                            _RecoveryStep.verifyOtpAndReset) {
                          final otpCode = otpController.text.trim();
                          final newPassword = newPasswordController.text.trim();
                          final confirmPassword =
                              confirmPasswordController.text.trim();

                          if (otpCode.length < 6 || recoveryToken == null) {
                            setDialogState(() {
                              dialogError = ref.tr('invalidOtp');
                            });
                            return;
                          }

                          if (newPassword.length < 6) {
                            setDialogState(() {
                              dialogError = ref.tr('passwordMinLength');
                            });
                            return;
                          }

                          if (newPassword != confirmPassword) {
                            setDialogState(() {
                              dialogError = ref.tr('passwordsDoNotMatch');
                            });
                            return;
                          }

                          setDialogState(() {
                            isSubmitting = true;
                            dialogError = null;
                          });

                          try {
                            final baseUrl =
                                await AppConfig.resolveAdminApiBaseUrl(
                              FirebaseFirestore.instance,
                            );
                            final effectiveBaseUrl = baseUrl.isNotEmpty
                                ? baseUrl
                                : 'https://pointage-api-zrot.onrender.com';
                            final uri = Uri.parse(
                              '$effectiveBaseUrl/users/verify-phone-otp-and-reset-password',
                            );
                            final resp = await http.post(
                              uri,
                              headers: {'Content-Type': 'application/json'},
                              body: jsonEncode({
                                'recoveryToken': recoveryToken,
                                'otp': otpCode,
                                'newPassword': newPassword,
                              }),
                            );

                            final data = jsonDecode(resp.body);

                            if (resp.statusCode == 200) {
                              if (dialogCtx.mounted && mounted) {
                                Navigator.pop(dialogCtx);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      ref.tr('passwordUpdatedSuccess'),
                                    ),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              }
                            } else {
                              setDialogState(() {
                                isSubmitting = false;
                                dialogError =
                                    data['message'] ?? ref.tr('invalidOtp');
                              });
                            }
                          } catch (err) {
                            setDialogState(() {
                              isSubmitting = false;
                              dialogError = err.toString();
                            });
                          }
                        }
                      },
                child: Text(
                  currentStep == _RecoveryStep.verifyOtpAndReset
                      ? ref.tr('save')
                      : ref.tr('apply'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: Theme.of(context).brightness == Brightness.dark
                  ? [const Color(0xFF181818), const Color(0xFF202020)]
                  : [const Color(0xFFEFF6FF), const Color(0xFFDBEAFE)],
            ),
          ),
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Card(
                  elevation: 8,
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color:
                                Theme.of(context).colorScheme.primaryContainer,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.qr_code_scanner_rounded,
                            size: 44,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Chez Le Pointage',
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          ref.tr('enterprisePortal'),
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                        ),
                        const SizedBox(height: 32),
                        TextField(
                          controller: email,
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(
                            labelText: ref.tr('emailAddress'),
                            prefixIcon: const Icon(Icons.email_outlined),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: password,
                          obscureText: obscurePassword,
                          decoration: InputDecoration(
                            labelText: ref.tr('passwordLabel'),
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              icon: Icon(
                                obscurePassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                              onPressed: () {
                                setState(
                                  () => obscurePassword = !obscurePassword,
                                );
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Checkbox(
                              value: remember,
                              onChanged: (v) =>
                                  setState(() => remember = v ?? true),
                            ),
                            Text(ref.tr('rememberMe')),
                            const Spacer(),
                            TextButton(
                              onPressed: _showForgotPasswordDialog,
                              child: Text(ref.tr('forgotPassword')),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: loading ? null : _login,
                            icon: loading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.login_rounded),
                            label: Text(
                              loading
                                  ? ref.tr('authenticating')
                                  : ref.tr('secureLogin'),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}
