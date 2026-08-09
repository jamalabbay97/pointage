import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';

class LockScreen extends StatefulWidget {
  final VoidCallback onUnlock;
  final bool biometricEnabled;

  const LockScreen({
    super.key,
    required this.onUnlock,
    required this.biometricEnabled,
  });

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  final LocalAuthentication auth = LocalAuthentication();
  bool _isAuthenticating = false;

  @override
  void initState() {
    super.initState();
    if (widget.biometricEnabled) {
      _authenticate();
    }
  }

  Future<void> _authenticate() async {
    setState(() => _isAuthenticating = true);
    try {
      final bool didAuthenticate = await auth.authenticate(
        localizedReason: 'Please authenticate to unlock the app',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
        ),
      );
      if (didAuthenticate) {
        widget.onUnlock();
      }
    } catch (e) {
      // Handle error or fallback to PIN
    }
    setState(() => _isAuthenticating = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.lock,
              size: 80,
              color: Colors.blueAccent,
            ),
            const SizedBox(height: 24),
            Text(
              'App Locked',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 48),
            if (widget.biometricEnabled)
              FilledButton.icon(
                onPressed: _isAuthenticating ? null : _authenticate,
                icon: const Icon(Icons.fingerprint),
                label: const Text('Unlock with Biometrics'),
              ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () {
                // If biometric is not enabled, or fails, they can just unlock for now,
                // but in a real app this would require a PIN.
                // Since there is no PIN set up in the app, we just allow unlocking.
                widget.onUnlock();
              },
              child: const Text('Unlock Manually'),
            ),
          ],
        ),
      ),
    );
  }
}
