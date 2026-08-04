import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/user_model.dart';
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
        title: const Text('User Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_alt_1),
            tooltip: 'Add User',
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
        label: const Text('Add Employee'),
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
                hintText: 'Search users by name or email...',
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
                    const Text(
                      'Role: ',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    ...['All', 'Admin', 'Manager', 'Employee'].map(
                      (role) => Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          label: Text(role),
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
                    const Text(
                      'Status: ',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    ...['All', 'Active', 'Disabled'].map(
                      (status) => Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          label: Text(status),
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
                          .where((u) => u.createdBy == currentUid)
                          .toList();
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
                              'No users found',
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      itemCount: users.length,
                      itemBuilder: (context, index) {
                        final user = users[index];
                        final isActive = user.isActive;
                        final isCurrentUser = user.uid == currentUid;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: _getRoleColor(user.role)
                                  .withValues(alpha: 0.15),
                              child: Icon(
                                _getRoleIcon(user.role),
                                color: _getRoleColor(user.role),
                              ),
                            ),
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    user.displayName,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      decoration: isActive
                                          ? null
                                          : TextDecoration.lineThrough,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _getRoleColor(user.role)
                                        .withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: _getRoleColor(user.role),
                                    ),
                                  ),
                                  child: Text(
                                    user.role.toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: _getRoleColor(user.role),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            subtitle: Text(
                              _userSubtitle(user, managersById),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            isThreeLine: true,
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
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
                                                    'User ${user.displayName} is now $newStatus',
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
                                                    _userFacingErrorMessage(e),
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
                                      _sendPasswordResetEmail(context, user);
                                    } else if (val == 'delete') {
                                      _confirmDeleteUser(context, user);
                                    }
                                  },
                                  itemBuilder: (context) => [
                                    const PopupMenuItem(
                                      value: 'edit',
                                      child: Row(
                                        children: [
                                          Icon(Icons.edit, size: 18),
                                          SizedBox(width: 8),
                                          Text('Edit Details'),
                                        ],
                                      ),
                                    ),
                                    const PopupMenuItem(
                                      value: 'reset',
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.lock_reset,
                                            size: 18,
                                            color: Colors.orange,
                                          ),
                                          SizedBox(width: 8),
                                          Text('Send Password Reset'),
                                        ],
                                      ),
                                    ),
                                    if (!isCurrentUser)
                                      const PopupMenuItem(
                                        value: 'delete',
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.delete,
                                              color: Colors.red,
                                              size: 18,
                                            ),
                                            SizedBox(width: 8),
                                            Text(
                                              'Delete User',
                                              style:
                                                  TextStyle(color: Colors.red),
                                            ),
                                          ],
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
    final currentUid = FirebaseAuth.instance.currentUser?.uid;

    if (currentUser?.isManager == true && currentUid != null) {
      return _db
          .collection('users')
          .where('createdBy', isEqualTo: currentUid)
          .snapshots();
    }

    return _db.collection('users').snapshots();
  }

  String _userSubtitle(UserModel user, Map<String, String> managersById) {
    final managerId = user.managerId ?? user.createdBy;
    final managerName = managerId == null
        ? null
        : managersById[managerId] ?? 'Manager ID: $managerId';
    final managerLine = managerName == null ? '' : '\nCreated by: $managerName';

    return '${user.email}\nDepartment: ${user.department}$managerLine';
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
    const chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#\$%^&.-_?*';
    final rnd = Random.secure();
    return List.generate(10, (index) => chars[rnd.nextInt(chars.length)])
        .join();
  }

  void _showUserDialog(BuildContext context, {UserModel? user}) {
    final isEdit = user != null;
    final nameController = TextEditingController(text: user?.displayName ?? '');
    final emailController = TextEditingController(text: user?.email ?? '');
    final deptController = TextEditingController(
      text: user?.department ?? 'Engineering',
    );
    final passwordController = TextEditingController();

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
          title: Text(isEdit ? 'Edit User Details' : 'Create New User Account'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Full Name',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: emailController,
                  enabled: !isEdit,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email Address',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                ),
                if (!isEdit) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: passwordController,
                    obscureText: obscurePassword,
                    decoration: InputDecoration(
                      labelText: 'Initial Password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.refresh, size: 20),
                            tooltip: 'Generate New Random Password',
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
                  decoration: const InputDecoration(
                    labelText: 'Department',
                    prefixIcon: Icon(Icons.business_outlined),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: role,
                  decoration: const InputDecoration(
                    labelText: 'Assigned Role',
                    prefixIcon: Icon(Icons.shield_outlined),
                  ),
                  items: [
                    if (canAssignPrivilegedRoles)
                      const DropdownMenuItem(
                        value: 'admin',
                        child: Text('Admin (Full Access)'),
                      ),
                    if (canAssignPrivilegedRoles)
                      const DropdownMenuItem(
                        value: 'manager',
                        child: Text('Manager (Dept Access)'),
                      ),
                    const DropdownMenuItem(
                      value: 'employee',
                      child: Text('Employee (Standard)'),
                    ),
                  ],
                  onChanged: isCurrentUser || !canAssignPrivilegedRoles
                      ? null
                      : (val) {
                          if (val != null) setDialogState(() => role = val);
                        },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.pop(dialogCtx),
              child: const Text('Cancel'),
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
                          const SnackBar(
                            content: Text('Please enter name and email'),
                          ),
                        );
                        return;
                      }

                      if (!isEdit &&
                          (passwordVal.isEmpty || passwordVal.length < 6)) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content:
                                Text('Password must be at least 6 characters'),
                          ),
                        );
                        return;
                      }

                      setDialogState(() => isSaving = true);

                      try {
                        if (!isEdit && await _userEmailExists(emailVal)) {
                          throw _CreateUserException(
                            'A user with $emailVal already exists.',
                          );
                        }

                        if (isEdit) {
                          final updateData = <String, dynamic>{
                            'displayName': name,
                            'department': dept.isEmpty ? 'General' : dept,
                          };
                          if (!isCurrentUser) {
                            updateData['role'] = role;
                          }
                          await _db
                              .collection('users')
                              .doc(user.uid)
                              .update(updateData);
                          if (dialogCtx.mounted) {
                            Navigator.pop(dialogCtx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content:
                                    Text('User $name updated successfully'),
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

                          // Save user document in Firestore using the generated Auth UID
                          await _db.collection('users').doc(newUid).set({
                            'uid': newUid,
                            'email': emailVal,
                            'displayName': name,
                            'role': role,
                            'status': 'active',
                            'department': dept.isEmpty ? 'General' : dept,
                            'createdAt': DateTime.now().toIso8601String(),
                            'createdBy': currentUid,
                            if (currentUid != null && role == 'employee')
                              'managerId': currentUid,
                          });

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
                  : Text(isEdit ? 'Save Changes' : 'Create Account'),
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

  Future<bool> _userEmailExists(String email) async {
    final snapshot = await _db
        .collection('users')
        .where('email', isEqualTo: email)
        .limit(1)
        .get();

    return snapshot.docs.isNotEmpty;
  }

  String _createUserAuthErrorMessage(
    FirebaseAuthException error,
    String email,
  ) {
    switch (error.code) {
      case 'email-already-in-use':
        return 'A Firebase Auth account already exists for $email. '
            'Use a different email address or edit the existing user.';
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
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 10),
            Text('User Account Created'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Account for $name ($role) has been successfully initialized in Firebase.',
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
                    'Email: $email',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  SelectableText(
                    'Password: $password',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.deepOrange,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'The user can now log in immediately using these credentials.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  void _sendPasswordResetEmail(BuildContext context, UserModel user) async {
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: user.email);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Password reset email sent to ${user.email}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send reset email: $e'),
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
        title: const Text('Delete User'),
        content: Text(
          'This removes ${user.displayName} from the app without signing in as '
          'that user. The Firebase Auth account must be removed by an Admin '
          'SDK backend or from Firebase Console.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              if (user.uid == FirebaseAuth.instance.currentUser?.uid) {
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content:
                          Text('You cannot delete your own admin account.'),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                }
                return;
              }

              try {
                await _db.collection('users').doc(user.uid).delete();
                if (ctx.mounted) Navigator.pop(ctx);
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
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
