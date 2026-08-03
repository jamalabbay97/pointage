import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
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
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  // Pre-load the saved theme BEFORE runApp so themeModeProvider
  // starts with its final value and never emits a second state change
  // (which was causing GoRouter to reset navigation and log out
  // Admin/Manager users due to a brief auth-loading window).
  final savedTheme = await loadSavedTheme();
  runApp(ProviderScope(
    overrides: [
      themeModeProvider.overrideWith((ref) => ThemeNotifier(savedTheme)),
    ],
    child: const ChezLePointageApp(),
  ),);

}

class RouterNotifier extends ChangeNotifier {
  final Ref _ref;

  RouterNotifier(this._ref) {
    _ref.listen(authStateProvider, (_, __) => notifyListeners());
  }

  String? redirect(BuildContext context, GoRouterState state) {
    final authState = _ref.read(authStateProvider);
    final isAuth = authState.valueOrNull != null;
    final isLoggingIn = state.matchedLocation == '/login';

    if (authState.isLoading) return null;

    if (!isAuth && !isLoggingIn) return '/login';
    if (isAuth && isLoggingIn) return '/dashboard';
    return null;
  }
}

final routerNotifierProvider = Provider<RouterNotifier>((ref) => RouterNotifier(ref));

final appRouterProvider = Provider<GoRouter>((ref) {
  final notifier = ref.watch(routerNotifierProvider);

  return GoRouter(
    initialLocation: '/dashboard',
    refreshListenable: notifier,
    redirect: notifier.redirect,
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/dashboard', builder: (_, __) => const DashboardScreen()),
      GoRoute(path: '/scan', builder: (_, __) => const QrScannerScreen()),
      GoRoute(path: '/history', builder: (_, __) => const HistoryScreen()),
      GoRoute(path: '/admin', builder: (_, __) => const AdminScreen()),
      GoRoute(path: '/admin/users', builder: (_, __) => const UserManagementScreen()),
      GoRoute(path: '/admin/roles', builder: (_, __) => const RoleManagementScreen()),
      GoRoute(path: '/admin/qr', builder: (_, __) => const QrGeneratorScreen()),
      GoRoute(path: '/admin/settings', builder: (_, __) => const SystemSettingsScreen()),
      GoRoute(path: '/admin/reports', builder: (_, __) => const AdminReportsScreen()),
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
