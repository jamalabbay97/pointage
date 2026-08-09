import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../settings/data/settings_provider.dart';
import 'lock_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AppLockWrapper extends ConsumerStatefulWidget {
  final Widget child;

  const AppLockWrapper({super.key, required this.child});

  @override
  ConsumerState<AppLockWrapper> createState() => _AppLockWrapperState();
}

class _AppLockWrapperState extends ConsumerState<AppLockWrapper>
    with WidgetsBindingObserver {
  DateTime? _pausedTime;
  bool _isLocked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (FirebaseAuth.instance.currentUser == null) {
      return; // Don't lock if not logged in
    }

    final userSettings = ref.read(userSettingsProvider).valueOrNull;
    if (userSettings == null) return;

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _pausedTime ??= DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      if (_pausedTime != null) {
        final duration = DateTime.now().difference(_pausedTime!);
        final lockTimeoutString = userSettings.autoLockTimeout;

        int timeoutMinutes = -1;
        if (lockTimeoutString == '1 minute') timeoutMinutes = 1;
        if (lockTimeoutString == '5 minutes') timeoutMinutes = 5;
        if (lockTimeoutString == '15 minutes') timeoutMinutes = 15;

        if (timeoutMinutes != -1 && duration.inMinutes >= timeoutMinutes) {
          setState(() {
            _isLocked = true;
          });
        }
        _pausedTime = null;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final userSettings = ref.watch(userSettingsProvider).valueOrNull;

    if (_isLocked && FirebaseAuth.instance.currentUser != null) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: LockScreen(
          biometricEnabled: userSettings?.biometricEnabled ?? false,
          onUnlock: () {
            setState(() {
              _isLocked = false;
              _pausedTime = null;
            });
          },
        ),
      );
    }

    return widget.child;
  }
}
