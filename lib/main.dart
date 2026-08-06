import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
import 'core/utils/async_timeout.dart';
import 'core/widgets/splash_screen.dart';
import 'features/admin/presentation/admin_screen.dart';
import 'features/admin/presentation/user_management_screen.dart';
import 'features/admin/presentation/role_management_screen.dart';
import 'features/admin/presentation/qr_generator_screen.dart';
import 'features/admin/presentation/system_settings_screen.dart';
import 'features/admin/presentation/admin_reports_screen.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/dashboard/presentation/dashboard_screen.dart';
import 'features/history/presentation/history_screen.dart';
import 'features/scanner/presentation/qr_scanner_screen.dart';
import 'features/profile/presentation/profile_screen.dart';
import 'features/settings/presentation/settings_screen.dart';
import 'features/auth/domain/auth_provider.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const BootstrapApp());
}

/// Shows a splash immediately while Firebase and preferences initialize,
/// avoiding a blank white screen on cold start (especially on slow networks).
class BootstrapApp extends StatefulWidget {
  const BootstrapApp({super.key});

  @override
  State<BootstrapApp> createState() => _BootstrapAppState();
}

class _BootstrapAppState extends State<BootstrapApp> {
  ThemeMode _savedTheme = ThemeMode.system;
  String? _initError;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      await withTimeout(
        Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        ),
        duration: const Duration(seconds: 30),
        label: 'Firebase initialization timed out',
      );
      _savedTheme = await withTimeout(
        loadSavedTheme(),
        duration: const Duration(seconds: 8),
        label: 'Theme loading timed out',
      ).catchError((_) => ThemeMode.system);
    } catch (e) {
      _initError = e.toString();
    }

    if (mounted) {
      setState(() => _ready = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        initialRoute: '/',
        onGenerateRoute: (_) => MaterialPageRoute(
          builder: (_) =>
              const SplashScreen(message: 'Starting application...'),
        ),
      );
    }

    if (_initError != null) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: _StartupErrorScreen(
          message: _initError!,
          onRetry: () {
            setState(() {
              _ready = false;
              _initError = null;
            });
            _initialize();
          },
        ),
      );
    }

    return ProviderScope(
      overrides: [
        themeModeProvider.overrideWith((ref) => ThemeNotifier(_savedTheme)),
      ],
      child: const ChezLePointageApp(),
    );
  }
}

class _StartupErrorScreen extends StatelessWidget {
  const _StartupErrorScreen({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.cloud_off_rounded,
                size: 56,
                color: Colors.redAccent,
              ),
              const SizedBox(height: 16),
              Text(
                'Unable to start',
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class RouterNotifier extends ChangeNotifier {
  final Ref _ref;

  RouterNotifier(this._ref) {
    _ref.listen(authStateProvider, (_, __) => notifyListeners());
  }

  String? redirect(BuildContext context, GoRouterState state) {
    final authState = _ref.read(authStateProvider);
    final location = state.matchedLocation;
    final isSplash = location == '/';
    final isLoggingIn = location == '/login';

    if (authState.isLoading) {
      return isSplash ? null : '/';
    }

    final isAuth = authState.valueOrNull != null;

    if (!isAuth) {
      return isLoggingIn ? null : '/login';
    }

    if (isLoggingIn || isSplash) return '/dashboard';
    return null;
  }
}

final routerNotifierProvider =
    Provider<RouterNotifier>((ref) => RouterNotifier(ref));

final appRouterProvider = Provider<GoRouter>((ref) {
  final notifier = ref.watch(routerNotifierProvider);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: notifier,
    redirect: notifier.redirect,
    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(title: const Text('Navigation error')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                size: 48,
                color: Colors.redAccent,
              ),
              const SizedBox(height: 16),
              Text(
                state.error?.toString() ?? 'Unknown routing error',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () => context.go('/'),
                child: const Text('Go to home'),
              ),
            ],
          ),
        ),
      ),
    ),
    routes: [
      GoRoute(path: '/', builder: (_, __) => const SplashScreen()),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/dashboard', builder: (_, __) => const DashboardScreen()),
      GoRoute(path: '/scan', builder: (_, __) => const QrScannerScreen()),
      GoRoute(path: '/history', builder: (_, __) => const HistoryScreen()),
      GoRoute(path: '/admin', builder: (_, __) => const AdminScreen()),
      GoRoute(
        path: '/admin/users',
        builder: (_, __) => const UserManagementScreen(),
      ),
      GoRoute(
        path: '/admin/roles',
        builder: (_, __) => const RoleManagementScreen(),
      ),
      GoRoute(
        path: '/admin/qr',
        builder: (_, __) => const QrGeneratorScreen(),
      ),
      GoRoute(
        path: '/admin/settings',
        builder: (_, __) => const SystemSettingsScreen(),
      ),
      GoRoute(
        path: '/admin/reports',
        builder: (_, __) => const AdminReportsScreen(),
      ),
      GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
      GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
    ],
  );
});

class ChezLePointageApp extends ConsumerWidget {
  const ChezLePointageApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'Chez Le Pointage',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      routerConfig: ref.watch(appRouterProvider),
      debugShowCheckedModeBanner: false,
    );
  }
}
