import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:local_auth/local_auth.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/app_translations.dart';
import '../../../core/utils/async_timeout.dart';
import '../domain/user_sync_service.dart';

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
                              onPressed: () async {
                                if (email.text.trim().isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        ref.tr('enterEmailFirst'),
                                      ),
                                    ),
                                  );
                                  return;
                                }
                                try {
                                  await withTimeout(
                                    FirebaseAuth.instance
                                        .sendPasswordResetEmail(
                                      email: email.text.trim(),
                                    ),
                                    duration: const Duration(seconds: 20),
                                    label: 'Password reset request timed out',
                                  );
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          ref.tr('passwordResetEmailSent'),
                                        ),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                  }
                                } catch (err) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(err.toString()),
                                        backgroundColor: Colors.redAccent,
                                      ),
                                    );
                                  }
                                }
                              },
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
