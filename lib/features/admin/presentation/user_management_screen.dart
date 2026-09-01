import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/config/app_config.dart';
import '../../../core/models/user_model.dart';
import '../../../core/services/app_translations.dart';
import '../../../core/services/user_deletion_api.dart';
import '../../auth/domain/auth_provider.dart';

class _CreateUserException implements Exception {
  const _CreateUserException(this.message);

  final String message;
}

class UserManagementScreen extends ConsumerStatefulWidget {
  const UserManagementScreen({super.key});

  @override
  ConsumerState<UserManagementScreen> createState() =>
      _UserManagementScreenState();
}

class _UserManagementScreenState extends ConsumerState<UserManagementScreen> {
  final TextEditingController _searchController = TextEditingController();
  String searchQuery = '';
  String selectedRoleFilter = 'All';
  String selectedStatusFilter = 'All';

  final _db = FirebaseFirestore.instance;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(ref.tr('userManagement')),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_alt_1),
            tooltip: ref.tr('addUser'),
            onPressed: () => _showUserDialog(context),
          ),
        ],
      ),
      body: _isWide
          ? Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: _buildBody(),
              ),
            )
          : _buildBody(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showUserDialog(context),
        icon: const Icon(Icons.add),
        label: Text(ref.tr('addEmployee')),
      ),
    );
  }

  static bool get _isWide =>
      kIsWeb ||
      defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.linux;

  Widget _buildBody() {
    final currentUserAsync = ref.watch(currentUserModelProvider);
    final currentUser = currentUserAsync.valueOrNull;
    final isLoadingCurrentUser =
        currentUserAsync.isLoading && currentUser == null;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              SearchBar(
                controller: _searchController,
                hintText: ref.tr('searchUsers'),
                leading: const Icon(Icons.search),
                trailing: _searchController.text.isNotEmpty
                    ? [
                        IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => searchQuery = '');
                          },
                        ),
                      ]
                    : null,
                onChanged: (val) =>
                    setState(() => searchQuery = val.trim().toLowerCase()),
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    Text(
                      ref.tr('roleLabel'),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    ...[
                      'All',
                      if (currentUser?.isAdmin == true) 'Admin',
                      'Manager',
                      'Employee',
                    ].map(
                      (role) => Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          label: Text(
                            role == 'All'
                                ? ref.tr('all')
                                : (role == 'Admin'
                                    ? ref.tr('admin')
                                    : (role == 'Manager'
                                        ? ref.tr('manager')
                                        : ref.tr('employee'))),
                          ),
                          selected: selectedRoleFilter == role,
                          onSelected: (selected) {
                            if (selected) {
                              setState(() => selectedRoleFilter = role);
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      ref.tr('statusFilter'),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    ...['All', 'Active', 'Disabled'].map(
                      (status) => Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          label: Text(
                            status == 'All'
                                ? ref.tr('all')
                                : (status == 'Active'
                                    ? ref.tr('active')
                                    : ref.tr('disabled')),
                          ),
                          selected: selectedStatusFilter == status,
                          onSelected: (selected) {
                            if (selected) {
                              setState(() => selectedStatusFilter = status);
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: isLoadingCurrentUser
              ? const Center(child: CircularProgressIndicator())
              : StreamBuilder<QuerySnapshot>(
                  stream: _usersStream(currentUser),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.error_outline,
                              size: 48,
                              color: Colors.red,
                            ),
                            const SizedBox(height: 12),
                            Text('Error loading users: ${snapshot.error}'),
                          ],
                        ),
                      );
                    }

                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final currentUid = FirebaseAuth.instance.currentUser?.uid;
                    final docs = snapshot.data?.docs ?? [];
                    var users = docs
                        .map(
                          (d) => UserModel.fromJson(
                            d.data() as Map<String, dynamic>,
                            d.id,
                          ),
                        )
                        .toList();
                    final managersById = {
                      for (final u in users)
                        if (u.isManager || u.isAdmin) u.uid: u.displayName,
                    };
                    if (currentUser?.isManager == true) {
                      users = users
                          .where((u) => u.createdBy == currentUid || u.managerId == currentUid)
                          .toList();
                    }

                    // Hide Admin accounts for non-admin accounts
                    if (currentUser?.isAdmin != true) {
                      users = users.where((u) => !u.isAdmin).toList();
                    }

                    // Apply Filters
                    if (searchQuery.isNotEmpty) {
                      users = users.where((u) {
                        return u.displayName
                                .toLowerCase()
                                .contains(searchQuery) ||
                            u.email.toLowerCase().contains(searchQuery) ||
                            u.department.toLowerCase().contains(searchQuery);
                      }).toList();
                    }

                    if (selectedRoleFilter != 'All') {
                      users = users
                          .where(
                            (u) =>
                                u.role.toLowerCase() ==
                                selectedRoleFilter.toLowerCase(),
                          )
                          .toList();
                    }

                    if (selectedStatusFilter != 'All') {
                      users = users
                          .where(
                            (u) =>
                                u.status.toLowerCase() ==
                                selectedStatusFilter.toLowerCase(),
                          )
                          .toList();
                    }

                    if (users.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.people_outline,
                              size: 64,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              ref.tr('noUsersFound'),
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(color: Colors.grey),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.only(
                        left: 16,
                        right: 16,
                        top: 8,
                        bottom: 80,
                      ),
                      itemCount: users.length,
                      itemBuilder: (context, index) {
                        final user = users[index];
                        final isActive = user.isActive;
                        final isCurrentUser = user.uid == currentUid;

                        final managerId = user.managerId ?? user.createdBy;
                        final rawManagerName = managerId == null
                            ? null
                            : managersById[managerId] ?? 'ID: $managerId';
                        final managerLine = rawManagerName == null
                            ? null
                            : ref
                                .tr('createdByLine')
                                .replaceAll('{name}', rawManagerName);

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          elevation: 1,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 20,
                                      backgroundColor: _getRoleColor(user.role)
                                          .withValues(alpha: 0.15),
                                      child: Icon(
                                        _getRoleIcon(user.role),
                                        color: _getRoleColor(user.role),
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            user.displayName,
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.bold,
                                              decoration: isActive
                                                  ? null
                                                  : TextDecoration.lineThrough,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 4),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: _getRoleColor(user.role)
                                                  .withValues(alpha: 0.1),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              border: Border.all(
                                                color: _getRoleColor(user.role),
                                              ),
                                            ),
                                            child: Text(
                                              ref
                                                  .trRole(user.role)
                                                  .toUpperCase(),
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: _getRoleColor(user.role),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Switch(
                                      value: isActive,
                                      activeThumbColor: Colors.green,
                                      onChanged: isCurrentUser
                                          ? null
                                          : (val) async {
                                              final newStatus =
                                                  val ? 'active' : 'disabled';
                                              try {
                                                await _db
                                                    .collection('users')
                                                    .doc(user.uid)
                                                    .update({
                                                  'status': newStatus,
                                                });
                                                if (context.mounted) {
                                                  ScaffoldMessenger.of(context)
                                                      .showSnackBar(
                                                    SnackBar(
                                                      content: Text(
                                                        'User ${user.displayName} ${val ? ref.tr('userNowActive') : ref.tr('userNowDisabled')}',
                                                      ),
                                                      duration: const Duration(
                                                        seconds: 2,
                                                      ),
                                                    ),
                                                  );
                                                }
                                              } catch (e) {
                                                if (context.mounted) {
                                                  ScaffoldMessenger.of(context)
                                                      .showSnackBar(
                                                    SnackBar(
                                                      content: Text(
                                                        _userFacingErrorMessage(
                                                          e,
                                                        ),
                                                      ),
                                                      backgroundColor:
                                                          Colors.redAccent,
                                                    ),
                                                  );
                                                }
                                              }
                                            },
                                    ),
                                    PopupMenuButton<String>(
                                      onSelected: (val) {
                                        if (val == 'edit') {
                                          _showUserDialog(context, user: user);
                                        } else if (val == 'reset') {
                                          _sendPasswordResetEmail(
                                            context,
                                            user,
                                          );
                                        } else if (val == 'unlink_device') {
                                          _unlinkDevice(user);
                                        } else if (val == 'delete') {
                                          _confirmDeleteUser(context, user);
                                        }
                                      },
                                      itemBuilder: (context) => [
                                        PopupMenuItem(
                                          value: 'edit',
                                          child: Row(
                                            children: [
                                              const Icon(Icons.edit, size: 18),
                                              const SizedBox(width: 8),
                                              Text(ref.tr('editDetails')),
                                            ],
                                          ),
                                        ),
                                        PopupMenuItem(
                                          value: 'reset',
                                          child: Row(
                                            children: [
                                              const Icon(
                                                Icons.lock_reset,
                                                size: 18,
                                                color: Colors.orange,
                                              ),
                                              const SizedBox(width: 8),
                                              Text(ref.tr('resetPassword')),
                                            ],
                                          ),
                                        ),
                                        if (user.boundDeviceId != null &&
                                            user.boundDeviceId!.isNotEmpty)
                                          PopupMenuItem(
                                            value: 'unlink_device',
                                            child: Row(
                                              children: [
                                                const Icon(
                                                  Icons.phonelink_erase,
                                                  size: 18,
                                                  color: Colors.orange,
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  ref.tr('unlinkDevice'),
                                                  style: const TextStyle(
                                                    color: Colors.orange,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        if (!isCurrentUser)
                                          PopupMenuItem(
                                            value: 'delete',
                                            child: Row(
                                              children: [
                                                const Icon(
                                                  Icons.delete,
                                                  color: Colors.red,
                                                  size: 18,
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  ref.tr('deleteUser'),
                                                  style: const TextStyle(
                                                    color: Colors.red,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 8),
                                  child: Divider(height: 1, thickness: 0.5),
                                ),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.email_outlined,
                                      size: 14,
                                      color: Colors.grey.shade500,
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        user.email,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade400,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.business_outlined,
                                      size: 14,
                                      color: Colors.grey.shade500,
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        ref.tr('departmentLine').replaceAll(
                                              '{dept}',
                                              user.department,
                                            ),
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade400,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                if (managerLine != null &&
                                    managerLine.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.person_outline,
                                        size: 14,
                                        color: Colors.grey.shade500,
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          managerLine,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade400,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(
                                      user.boundDeviceId != null &&
                                              user.boundDeviceId!.isNotEmpty
                                          ? Icons.phone_android
                                          : Icons.phonelink_erase,
                                      size: 14,
                                      color: user.boundDeviceId != null &&
                                              user.boundDeviceId!.isNotEmpty
                                          ? Colors.green.shade400
                                          : Colors.grey.shade500,
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        user.boundDeviceId != null &&
                                                user.boundDeviceId!.isNotEmpty
                                            ? 'Device ID: ${user.boundDeviceId}'
                                            : ref.tr('noDeviceLinked'),
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: user.boundDeviceId != null &&
                                                  user.boundDeviceId!
                                                      .isNotEmpty
                                              ? Colors.green.shade300
                                              : Colors.grey.shade400,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }

  Stream<QuerySnapshot> _usersStream(UserModel? currentUser) {
    return _db.collection('users').snapshots();
  }

  Future<void> _unlinkDevice(UserModel user) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ref.tr('unlinkDevice')),
        content: Text(
          ref.tr('confirmUnlinkDevice').replaceAll('{name}', user.displayName),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(ref.tr('cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.orange.shade800,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(ref.tr('unlinkDevice')),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _db.collection('users').doc(user.uid).update({
          'boundDeviceId': FieldValue.delete(),
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                ref.tr('deviceUnlinked').replaceAll('{name}', user.displayName),
              ),
              backgroundColor: Colors.orange.shade800,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error unlinking device: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Color _getRoleColor(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return Colors.purple;
      case 'manager':
        return Colors.blue;
      default:
        return Colors.teal;
    }
  }

  IconData _getRoleIcon(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return Icons.admin_panel_settings;
      case 'manager':
        return Icons.supervisor_account;
      default:
        return Icons.badge;
    }
  }

  String _generatePassword() {
    const chars = '0123456789';
    final rnd = Random.secure();
    return List.generate(8, (index) => chars[rnd.nextInt(chars.length)])
        .join();
  }

  void _showUserDialog(BuildContext context, {UserModel? user}) {
    final isEdit = user != null;
    final nameController = TextEditingController(text: user?.displayName ?? '');
    final emailController = TextEditingController(text: user?.email ?? '');
    final phoneController =
        TextEditingController(text: user?.phoneNumber ?? '');
    final deptController = TextEditingController(
      text: user?.department ?? 'Engineering',
    );
    final passwordController = TextEditingController();
    final boundDeviceIdController = TextEditingController(
      text: user?.boundDeviceId ?? '',
    );

    // Location controllers (manager override)
    final locationLatController = TextEditingController(
      text: user?.assignedLocationLat?.toString() ?? '',
    );
    final locationLngController = TextEditingController(
      text: user?.assignedLocationLng?.toString() ?? '',
    );
    final locationRadiusController = TextEditingController(
      text: user?.assignedLocationRadius?.toString() ?? '500',
    );

    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    final isCurrentUser = user?.uid == currentUid;
    final currentUser = ref.read(currentUserModelProvider).valueOrNull;
    final canAssignPrivilegedRoles = currentUser?.isAdmin == true;
    String role =
        canAssignPrivilegedRoles ? (user?.role ?? 'employee') : 'employee';
    bool obscurePassword = true;
    bool isSaving = false;

    if (!isEdit) {
      passwordController.text = _generatePassword();
    }

    showDialog(
      context: context,
      barrierDismissible: !isSaving,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
            isEdit ? ref.tr('editUserDetails') : ref.tr('createNewUserAccount'),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: ref.tr('fullName'),
                    prefixIcon: const Icon(Icons.person_outline),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: emailController,
                  enabled: !isEdit,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: ref.tr('emailAddress'),
                    prefixIcon: const Icon(Icons.email_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: ref.tr('phoneNumber'),
                    hintText: ref.tr('phoneNumberHint'),
                    prefixIcon: const Icon(Icons.phone_outlined),
                  ),
                ),
                if (!isEdit) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: passwordController,
                    obscureText: obscurePassword,
                    decoration: InputDecoration(
                      labelText: ref.tr('initialPassword'),
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.refresh, size: 20),
                            tooltip: ref.tr('generatePasswordTooltip'),
                            onPressed: () {
                              setDialogState(() {
                                passwordController.text = _generatePassword();
                              });
                            },
                          ),
                          IconButton(
                            icon: Icon(
                              obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              size: 20,
                            ),
                            onPressed: () {
                              setDialogState(
                                () => obscurePassword = !obscurePassword,
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                TextField(
                  controller: deptController,
                  decoration: InputDecoration(
                    labelText: ref.tr('department'),
                    prefixIcon: const Icon(Icons.business_outlined),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: role,
                  decoration: InputDecoration(
                    labelText: ref.tr('assignedRole'),
                    prefixIcon: const Icon(Icons.shield_outlined),
                  ),
                  items: [
                    if (canAssignPrivilegedRoles)
                      DropdownMenuItem(
                        value: 'admin',
                        child: Text(ref.tr('adminRoleOption')),
                      ),
                    if (canAssignPrivilegedRoles)
                      DropdownMenuItem(
                        value: 'manager',
                        child: Text(ref.tr('managerRoleOption')),
                      ),
                    DropdownMenuItem(
                      value: 'employee',
                      child: Text(ref.tr('employeeRoleOption')),
                    ),
                  ],
                  onChanged: isCurrentUser || !canAssignPrivilegedRoles
                      ? null
                      : (val) {
                          if (val != null) setDialogState(() => role = val);
                        },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: boundDeviceIdController,
                  decoration: InputDecoration(
                    labelText: ref.tr('linkedDeviceId'),
                    hintText: ref.tr('noDeviceLinked'),
                    prefixIcon: const Icon(Icons.phone_android),
                    suffixIcon: boundDeviceIdController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, color: Colors.orange),
                            tooltip: ref.tr('unlinkDevice'),
                            onPressed: () {
                              setDialogState(() {
                                boundDeviceIdController.clear();
                              });
                            },
                          )
                        : null,
                  ),
                  onChanged: (_) => setDialogState(() {}),
                ),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    boundDeviceIdController.text.trim().isEmpty
                        ? ref.tr('noDeviceLinked')
                        : 'Worker is bound to this device for attendance.',
                    style: TextStyle(
                      fontSize: 11,
                      color: boundDeviceIdController.text.trim().isEmpty
                          ? Colors.orange.shade700
                          : Colors.green.shade700,
                    ),
                  ),
                ),
                // ── Manager Location Override Section ──────────────────────
                if (isEdit && currentUser?.isManager == true)
                  ..._buildLocationOverrideFields(
                    user: user,
                    currentUser: currentUser!,
                    locationLatController: locationLatController,
                    locationLngController: locationLngController,
                    locationRadiusController: locationRadiusController,
                    setDialogState: setDialogState,
                  ),
                // ──────────────────────────────────────────────────────────
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.pop(dialogCtx),
              child: Text(ref.tr('cancel')),
            ),
            FilledButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      final name = nameController.text.trim();
                      final emailVal =
                          emailController.text.trim().toLowerCase();
                      final passwordVal = passwordController.text;
                      final dept = deptController.text.trim();

                      if (name.isEmpty || emailVal.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(ref.tr('pleaseEnterNameEmail')),
                          ),
                        );
                        return;
                      }

                      if (!isEdit) {
                        if (passwordVal.isEmpty || passwordVal.length < 6) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(ref.tr('passwordMinLength')),
                            ),
                          );
                          return;
                        }
                        if (!RegExp(r'^\d+$').hasMatch(passwordVal)) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(ref.tr('passwordNumericOnly')),
                            ),
                          );
                          return;
                        }
                      }

                      setDialogState(() => isSaving = true);

                      try {
                        // Note: email-uniqueness is enforced by Firebase Auth
                        // (throws email-already-in-use). The Firestore query
                        // check was removed because Managers can only read
                        // their own employees, not the full users collection.
                        if (!isEdit) {
                          await _reconcileOrphanedAuthAccount(emailVal);
                        }

                        if (isEdit) {
                          final updateData = <String, dynamic>{
                            'displayName': name,
                            'phoneNumber': phoneController.text.trim(),
                            'department': dept.isEmpty ? 'General' : dept,
                          };
                          if (!isCurrentUser) {
                            updateData['role'] = role;
                          }

                          // ── Save manager location override ──────────────
                          if (currentUser?.isManager == true) {
                            final managerUid =
                                FirebaseAuth.instance.currentUser?.uid;
                            // Security: Only allow editing users belonging to
                            // this manager.
                            final belongsToManager =
                                user.managerId == managerUid ||
                                    user.createdBy == managerUid;
                            if (belongsToManager && managerUid != null) {
                              final latVal = double.tryParse(
                                locationLatController.text.trim(),
                              );
                              final lngVal = double.tryParse(
                                locationLngController.text.trim(),
                              );
                              final radiusVal = double.tryParse(
                                locationRadiusController.text.trim(),
                              );
                              if (latVal != null && lngVal != null) {
                                updateData['assignedLocationLat'] = latVal;
                                updateData['assignedLocationLng'] = lngVal;
                                updateData['assignedLocationRadius'] =
                                    radiusVal ?? 500.0;
                                updateData['locationAssignedBy'] = managerUid;
                              } else {
                                // Empty fields = remove the override
                                updateData['assignedLocationLat'] =
                                    FieldValue.delete();
                                updateData['assignedLocationLng'] =
                                    FieldValue.delete();
                                updateData['assignedLocationRadius'] =
                                    FieldValue.delete();
                                updateData['locationAssignedBy'] =
                                    FieldValue.delete();
                              }
                            }
                          }
                          // ───────────────────────────────────────────────

                          if (boundDeviceIdController.text.trim().isEmpty) {
                            updateData['boundDeviceId'] = FieldValue.delete();
                          } else {
                            updateData['boundDeviceId'] =
                                boundDeviceIdController.text.trim();
                          }

                          await _db
                              .collection('users')
                              .doc(user.uid)
                              .update(updateData);
                          if (dialogCtx.mounted) {
                            Navigator.pop(dialogCtx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  ref
                                      .tr('userUpdatedSuccess')
                                      .replaceAll('{name}', name),
                                ),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        } else {
                          final newUid =
                              await _createAuthUserWithoutSwitchingSession(
                            email: emailVal,
                            password: passwordVal,
                          );

                          final isNewManager = role == 'manager';
                          final managerSchedule =
                              currentUser?.scheduleType ?? 'standard';

                          final newUserData = <String, dynamic>{
                            'uid': newUid,
                            'email': emailVal,
                            'displayName': name,
                            'phoneNumber': phoneController.text.trim(),
                            'role': role,
                            'status': 'active',
                            'department': dept.isEmpty ? 'General' : dept,
                            'createdAt': DateTime.now().toIso8601String(),
                            'createdBy': currentUid,
                            if (currentUid != null && role == 'employee')
                              'managerId': currentUid,
                            'scheduleType':
                                isNewManager ? 'standard' : managerSchedule,
                            'isFirstLogin': isNewManager,
                          };

                          if (boundDeviceIdController.text.trim().isNotEmpty) {
                            newUserData['boundDeviceId'] =
                                boundDeviceIdController.text.trim();
                          }

                          // Save user document in Firestore using the generated Auth UID
                          await _db
                              .collection('users')
                              .doc(newUid)
                              .set(newUserData);

                          if (dialogCtx.mounted) {
                            Navigator.pop(dialogCtx);
                            _showUserCreatedSuccessDialog(
                              context,
                              name,
                              emailVal,
                              passwordVal,
                              role,
                            );
                          }
                        }
                      } catch (e) {
                        if (dialogCtx.mounted) {
                          setDialogState(() => isSaving = false);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(_userFacingErrorMessage(e)),
                              backgroundColor: Colors.redAccent,
                            ),
                          );
                        }
                      }
                    },
              child: isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      isEdit ? ref.tr('saveChanges') : ref.tr('createAccount'),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  /// Creates the Firebase Auth user in an isolated FirebaseApp so the current
  /// Admin/Manager session is never replaced by the new user's session.
  Future<String> _createAuthUserWithoutSwitchingSession({
    required String email,
    required String password,
  }) async {
    final primaryAuth = FirebaseAuth.instance;
    final originalUid = primaryAuth.currentUser?.uid;
    FirebaseApp? secondaryApp;

    try {
      final appName =
          'AdminUserCreator_${DateTime.now().microsecondsSinceEpoch}';
      secondaryApp = await Firebase.initializeApp(
        name: appName,
        options: Firebase.app().options,
      );
      final secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);
      try {
        await secondaryAuth.setPersistence(Persistence.NONE);
      } catch (_) {
        // Ignore on platforms that do not support setPersistence
      }
      final cred = await secondaryAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final newUid = cred.user!.uid;
      await secondaryAuth.signOut();

      if (primaryAuth.currentUser?.uid != originalUid) {
        throw const _CreateUserException(
          'The current admin session changed while creating the user. Please sign in again and retry.',
        );
      }

      return newUid;
    } on FirebaseAuthException catch (authErr) {
      throw _CreateUserException(_createUserAuthErrorMessage(authErr, email));
    } on _CreateUserException {
      rethrow;
    } catch (_) {
      throw const _CreateUserException(
        'Could not create the Firebase Auth account. Please try again.',
      );
    } finally {
      await secondaryApp?.delete();
    }
  }

  String _createUserAuthErrorMessage(
    FirebaseAuthException error,
    String email,
  ) {
    switch (error.code) {
      case 'email-already-in-use':
        return 'A Firebase Auth account already exists for $email. '
            'If this user was partially created before, configure the Admin API '
            'in System Settings and try again, or use a different email address.';
      case 'invalid-email':
        return 'Enter a valid email address.';
      case 'weak-password':
        return 'Password must be at least 6 characters.';
      case 'operation-not-allowed':
        return 'Email/password sign-in is not enabled for this Firebase project.';
      default:
        return error.message ??
            'Could not create the Firebase Auth account. Please try again.';
    }
  }

  String _userFacingErrorMessage(Object error) {
    if (error is _CreateUserException) {
      return error.message;
    }

    if (error is UserDeletionApiException) {
      return error.message;
    }

    if (error is FirebaseException) {
      switch (error.code) {
        case 'permission-denied':
          return 'You do not have permission to update this user. Verify your admin role is active in Firestore.';
        case 'unavailable':
          return 'Firebase is currently unavailable. Please try again.';
      }
    }

    return 'Something went wrong. Please try again.';
  }

  void _showUserCreatedSuccessDialog(
    BuildContext context,
    String name,
    String email,
    String password,
    String role,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.green),
            const SizedBox(width: 10),
            Text(ref.tr('userCreatedSuccessTitle')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              ref
                  .tr('userCreatedSuccessSub')
                  .replaceAll('{name}', name)
                  .replaceAll('{role}', ref.trRole(role)),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SelectableText(
                    '${ref.tr('emailAddress')}: $email',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  SelectableText(
                    '${ref.tr('password')}: $password',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.deepOrange,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              ref.tr('initialCredentialsInfo'),
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(ref.tr('done')),
          ),
        ],
      ),
    );
  }

  Future<String> _requireAdminApiBaseUrl() async {
    final baseUrl = await AppConfig.resolveAdminApiBaseUrl(_db);
    if (baseUrl.isEmpty) {
      throw const UserDeletionApiException(
        'The admin API is not configured. Set the Admin API Base URL in '
        'System Settings, or start the app with '
        '--dart-define=POINTAGE_API_BASE_URL=<backend URL>.',
      );
    }
    return baseUrl;
  }

  Future<String> _requireIdToken() async {
    final idToken = await FirebaseAuth.instance.currentUser?.getIdToken();
    if (idToken == null) {
      throw const UserDeletionApiException(
        'Your admin session expired. Please sign in again and retry.',
      );
    }
    return idToken;
  }

  Future<void> _reconcileOrphanedAuthAccount(String email) async {
    final baseUrl = await AppConfig.resolveAdminApiBaseUrl(_db);
    if (baseUrl.isEmpty) return;

    final idToken = await _requireIdToken();
    final lookup = await lookupUserByEmailThroughAdminApi(
      baseUrl: baseUrl,
      email: email,
      idToken: idToken,
    );

    if (lookup.uid == null) return;
    if (lookup.hasFirestoreProfile) {
      throw _CreateUserException('A user with $email already exists.');
    }

    await deleteUserThroughAdminApi(
      baseUrl: baseUrl,
      uid: lookup.uid!,
      idToken: idToken,
    );
  }

  Future<void> _deleteUserCompletely(String uid) async {
    final baseUrl = await _requireAdminApiBaseUrl();
    final idToken = await _requireIdToken();

    await deleteUserThroughAdminApi(
      baseUrl: baseUrl,
      uid: uid,
      idToken: idToken,
    );
  }

  void _sendPasswordResetEmail(BuildContext context, UserModel user) async {
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: user.email);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              ref
                  .tr('passwordResetEmailSent')
                  .replaceAll('{email}', user.email),
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              ref
                  .tr('failedToSendResetEmail')
                  .replaceAll('{error}', e.toString()),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _confirmDeleteUser(BuildContext context, UserModel user) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ref.tr('confirmDeleteUserTitle')),
        content: Text(
          ref
              .tr('confirmDeleteUserBody')
              .replaceAll('{name}', user.displayName),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(ref.tr('cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              if (user.uid == FirebaseAuth.instance.currentUser?.uid) {
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(ref.tr('cannotDeleteOwnAccount')),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                }
                return;
              }

              try {
                await _deleteUserCompletely(user.uid);
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        ref
                            .tr('userDeletedSuccess')
                            .replaceAll('{name}', user.displayName),
                      ),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(_userFacingErrorMessage(e)),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                }
              }
            },
            child: Text(ref.tr('deleteUser')),
          ),
        ],
      ),
    );
  }

  // ── Manager Location Override UI ─────────────────────────────────────────────

  /// Builds the Location Override section shown inside the user edit dialog
  /// when the current user is a manager editing one of their own employees.
  List<Widget> _buildLocationOverrideFields({
    required UserModel user,
    required UserModel currentUser,
    required TextEditingController locationLatController,
    required TextEditingController locationLngController,
    required TextEditingController locationRadiusController,
    required StateSetter setDialogState,
  }) {
    final managerUid = FirebaseAuth.instance.currentUser?.uid;
    // Only show if this user belongs to this manager
    final belongsToManager =
        user.managerId == managerUid || user.createdBy == managerUid;
    if (!belongsToManager) return [];

    final hasLocation =
        user.assignedLocationLat != null && user.assignedLocationLng != null;

    return [
      const SizedBox(height: 20),
      const Divider(),
      const SizedBox(height: 8),
      Row(
        children: [
          const Icon(
            Icons.location_on_outlined,
            size: 18,
            color: Colors.teal,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              ref.tr('locationOverrideTitle'),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ),
          if (hasLocation)
            TextButton.icon(
              icon: const Icon(Icons.clear, size: 16),
              label: Text(ref.tr('clearLocation')),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              onPressed: () {
                setDialogState(() {
                  locationLatController.clear();
                  locationLngController.clear();
                });
              },
            ),
        ],
      ),
      const SizedBox(height: 4),
      Text(
        ref.tr('locationOverrideDesc'),
        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(
            child: TextField(
              controller: locationLatController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
              decoration: InputDecoration(
                labelText: ref.tr('latitude'),
                prefixIcon: const Icon(Icons.explore_outlined, size: 18),
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: locationLngController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
              decoration: InputDecoration(
                labelText: ref.tr('longitude'),
                prefixIcon: const Icon(Icons.explore_outlined, size: 18),
                isDense: true,
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 10),
      TextField(
        controller: locationRadiusController,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: ref.tr('radiusMeters'),
          prefixIcon: const Icon(Icons.radar_outlined, size: 18),
          isDense: true,
        ),
      ),
      const SizedBox(height: 10),
      SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          icon: const Icon(Icons.my_location, size: 16),
          label: Text(ref.tr('useCurrentGps')),
          onPressed: () async {
            try {
              final pos = await Geolocator.getCurrentPosition(
                desiredAccuracy: LocationAccuracy.high,
              );
              setDialogState(() {
                locationLatController.text = pos.latitude.toString();
                locationLngController.text = pos.longitude.toString();
              });
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${ref.tr('couldNotGetGps')}: $e'),
                  ),
                );
              }
            }
          },
        ),
      ),
    ];
  }

  /// Shows the bulk location assignment dialog for a Manager, allowing them to
  /// apply a single location to ALL users they manage.
  // ignore: unused_element
  void _showManagerBulkLocationDialog(
    BuildContext context,
    UserModel currentUser,
  ) {
    final latController = TextEditingController();
    final lngController = TextEditingController();
    final radiusController = TextEditingController(text: '500');
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.location_on, color: Colors.teal),
              SizedBox(width: 10),
              Expanded(child: Text('Set Location for All My Users')),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'This will assign the specified location to all employees '
                  'under your management. It will override the Admin global '
                  'location for your team.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: latController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                          signed: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Latitude',
                          prefixIcon: Icon(Icons.explore_outlined, size: 18),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: lngController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                          signed: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Longitude',
                          prefixIcon: Icon(Icons.explore_outlined, size: 18),
                          isDense: true,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: radiusController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Radius (meters)',
                    prefixIcon: Icon(Icons.radar_outlined, size: 18),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.my_location, size: 16),
                    label: const Text('Use Current GPS Position'),
                    onPressed: () async {
                      try {
                        final pos = await Geolocator.getCurrentPosition(
                          desiredAccuracy: LocationAccuracy.high,
                        );
                        setDialogState(() {
                          latController.text = pos.latitude.toString();
                          lngController.text = pos.longitude.toString();
                        });
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Could not get GPS: $e'),
                            ),
                          );
                        }
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      final lat = double.tryParse(latController.text.trim());
                      final lng = double.tryParse(lngController.text.trim());
                      final radius =
                          double.tryParse(radiusController.text.trim()) ??
                              500.0;
                      if (lat == null || lng == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Please enter valid latitude and longitude',
                            ),
                          ),
                        );
                        return;
                      }
                      setDialogState(() => isSaving = true);
                      try {
                        final managerUid =
                            FirebaseAuth.instance.currentUser?.uid;
                        if (managerUid == null) return;

                        // Fetch all users belonging to this manager
                        final usersSnap = await _db
                            .collection('users')
                            .where('createdBy', isEqualTo: managerUid)
                            .get();

                        final batch = _db.batch();
                        for (final doc in usersSnap.docs) {
                          batch.update(doc.reference, {
                            'assignedLocationLat': lat,
                            'assignedLocationLng': lng,
                            'assignedLocationRadius': radius,
                            'locationAssignedBy': managerUid,
                          });
                        }
                        await batch.commit();

                        if (ctx.mounted) Navigator.pop(ctx);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Location applied to ${usersSnap.docs.length} user(s)',
                              ),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      } catch (e) {
                        setDialogState(() => isSaving = false);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Failed to apply location: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
              child: isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Apply to All My Users'),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
}
