import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  DateTime now = DateTime.now();
  Timer? timer;
  @override
  void initState() {
    super.initState();
    timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => setState(() => now = DateTime.now()),
    );
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            onPressed: () => context.go('/admin'),
            icon: const Icon(Icons.admin_panel_settings),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user?.displayName ?? 'Employee',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  Text('Employee ID: ${user?.uid ?? 'N/A'}'),
                  const SizedBox(height: 16),
                  Text(DateFormat.yMMMMEEEEd().format(now)),
                  Text(
                    DateFormat.Hms().format(now),
                    style: Theme.of(context).textTheme.displaySmall,
                  ),
                  const Chip(label: Text('Today: Not checked in')),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const _Action(
            title: 'Scan QR Code',
            icon: Icons.qr_code_scanner,
            route: '/scan',
          ),
          const _Action(
            title: 'Attendance History',
            icon: Icons.history,
            route: '/history',
          ),
          const _Action(
            title: 'Profile',
            icon: Icons.person,
            route: '/dashboard',
          ),
          const _Action(
            title: 'Settings',
            icon: Icons.settings,
            route: '/dashboard',
          ),
        ],
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({required this.title, required this.icon, required this.route});
  final String title, route;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: FilledButton.tonalIcon(
          onPressed: () => context.go(route),
          icon: Icon(icon),
          label: Text(title),
        ),
      );
}
