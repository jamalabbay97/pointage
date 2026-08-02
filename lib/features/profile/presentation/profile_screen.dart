import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/domain/auth_provider.dart';
import '../../../core/widgets/web_layout.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = FirebaseAuth.instance.currentUser;
    final userModel = ref.watch(currentUserModelProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Employee Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit Profile',
            onPressed: () => _showEditProfileDialog(context, user, userModel?.displayName),
          ),
        ],
      ),
      body: WebLayout(
        child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 54,
                  backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                  child: Text(
                    (userModel?.displayName.isNotEmpty == true)
                        ? userModel!.displayName[0].toUpperCase()
                        : 'E',
                    style: TextStyle(
                      fontSize: 44,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.verified, color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Center(
            child: Text(
              userModel?.displayName ?? user?.displayName ?? 'Employee',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
          Center(
            child: Text(
              user?.email ?? 'N/A',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.grey.shade600,
                  ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Chip(
                avatar: const Icon(Icons.badge_outlined, size: 16),
                label: Text((userModel?.role ?? 'employee').toUpperCase()),
                backgroundColor: Colors.blue.withValues(alpha: 0.1),
              ),
              const SizedBox(width: 8),
              Chip(
                avatar: const Icon(Icons.business_outlined, size: 16),
                label: Text(userModel?.department ?? 'General'),
                backgroundColor: Colors.purple.withValues(alpha: 0.1),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Account Information',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const Divider(height: 24),
                  _buildProfileRow('User ID', user?.uid ?? 'N/A'),
                  _buildProfileRow('Account Status', (userModel?.status ?? 'active').toUpperCase()),
                  _buildProfileRow('Department', userModel?.department ?? 'General'),
                  _buildProfileRow('Auth Provider', user?.providerData.firstOrNull?.providerId ?? 'password'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () async {
                await FirebaseAuth.instance.signOut();
              },
              icon: const Icon(Icons.logout),
              label: const Text('Sign Out'),
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
            ),
          ),
        ],
        ),
      ),
    );
  }

  Widget _buildProfileRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade600)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  void _showEditProfileDialog(BuildContext context, User? user, String? currentName) {
    if (user == null) return;
    final controller = TextEditingController(text: currentName ?? user.displayName ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Display Name'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Display Name'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isNotEmpty) {
                await user.updateDisplayName(newName);
                await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
                  'displayName': newName,
                });
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
