import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/services/app_translations.dart';
import '../../../core/widgets/web_layout.dart';
import '../../auth/domain/auth_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  static ImageProvider? getProfileImageProvider(String? photoUrl) {
    if (photoUrl == null || photoUrl.trim().isEmpty) return null;
    final url = photoUrl.trim();
    if (url.startsWith('data:image')) {
      try {
        final base64Data = url.split(',').last;
        final bytes = base64Decode(base64Data);
        return MemoryImage(bytes);
      } catch (_) {
        return null;
      }
    } else if (url.startsWith('http://') || url.startsWith('https://')) {
      return NetworkImage(url);
    }
    return null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = FirebaseAuth.instance.currentUser;
    final userModel = ref.watch(currentUserModelProvider).valueOrNull;

    final photoUrl = userModel?.photoUrl ?? user?.photoURL;
    final imageProvider = getProfileImageProvider(photoUrl);

    return Scaffold(
      appBar: AppBar(
        title: Text(ref.tr('userProfile')),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: ref.tr('editProfile'),
            onPressed: () => _showEditProfileDialog(
              context,
              ref,
              user,
              userModel?.photoUrl ?? user?.photoURL,
              userModel?.phoneNumber,
            ),
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
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Theme.of(context).colorScheme.primary,
                        width: 2.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(context)
                              .colorScheme
                              .primary
                              .withValues(alpha: 0.25),
                          blurRadius: 18,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: CircleAvatar(
                      radius: 54,
                      backgroundColor:
                          Theme.of(context).colorScheme.primaryContainer,
                      backgroundImage: imageProvider,
                      child: imageProvider == null
                          ? Text(
                              (userModel?.displayName.isNotEmpty == true)
                                  ? userModel!.displayName[0].toUpperCase()
                                  : 'E',
                              style: TextStyle(
                                fontSize: 44,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            )
                          : null,
                    ),
                  ),
                  Positioned(
                    bottom: 4,
                    right: 4,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(
                        Icons.verified_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Center(
              child: Text(
                userModel?.displayName ??
                    user?.displayName ??
                    ref.tr('employee'),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.4,
                    ),
              ),
            ),
            const SizedBox(height: 4),
            Center(
              child: Text(
                user?.email ?? 'N/A',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFF94A3B8)
                          : const Color(0xFF64748B),
                    ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3B82F6).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: const Color(0xFF3B82F6).withValues(alpha: 0.25),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.badge_outlined,
                        size: 15,
                        color: Color(0xFF3B82F6),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        ref.trRole(userModel?.role ?? 'employee').toUpperCase(),
                        style: const TextStyle(
                          color: Color(0xFF3B82F6),
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B5CF6).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: const Color(0xFF8B5CF6).withValues(alpha: 0.25),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.business_outlined,
                        size: 15,
                        color: Color(0xFF8B5CF6),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        userModel?.department ?? 'General',
                        style: const TextStyle(
                          color: Color(0xFF8B5CF6),
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF131B2E)
                    : Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF1E293B)
                      : const Color(0xFFE2E8F0),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? const Color.fromRGBO(0, 0, 0, 0.3)
                        : const Color.fromRGBO(15, 23, 42, 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ref.tr('accountInfo'),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Divider(height: 1),
                  const SizedBox(height: 16),
                  _buildProfileRow(
                    ref.tr('status'),
                    ref.trStatus(userModel?.status ?? 'active').toUpperCase(),
                  ),
                  _buildProfileRow(
                    ref.tr('department'),
                    userModel?.department ?? 'General',
                  ),
                  _buildProfileRow(
                    ref.tr('authProvider'),
                    ref.trAuthProvider(
                      user?.providerData.firstOrNull?.providerId ?? 'password',
                    ),
                  ),
                  _buildProfileRow(
                    ref.tr('phoneNumber'),
                    userModel?.phoneNumber ?? 'N/A',
                  ),
                  if (userModel?.isAdminOrManager == true)
                    _buildProfileRow(
                      ref.tr('linkedDeviceId'),
                      ref.tr('unrestrictedDevice'),
                    )
                  else
                    _buildProfileRow(
                      ref.tr('linkedDeviceId'),
                      userModel?.boundDeviceId ?? ref.tr('noDeviceLinked'),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF131B2E)
                    : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF1E293B)
                      : const Color(0xFFE2E8F0),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? const Color.fromRGBO(0, 0, 0, 0.3)
                        : const Color.fromRGBO(15, 23, 42, 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                clipBehavior: Clip.antiAlias,
                borderRadius: BorderRadius.circular(20),
                child: ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.settings_outlined,
                      color: Color(0xFF6366F1),
                      size: 20,
                    ),
                  ),
                  title: Text(
                    ref.tr('settingsPrefs'),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  subtitle: Text(
                    ref.tr('themeLangSec'),
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFF94A3B8)
                          : const Color(0xFF64748B),
                    ),
                  ),
                  trailing:
                      const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                  onTap: () => context.push('/settings'),
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton.icon(
                onPressed: () async {
                  const storage = FlutterSecureStorage();
                  await storage.delete(key: 'email');
                  await storage.delete(key: 'password');
                  await performExplicitSignOut(ref);
                },
                icon: const Icon(Icons.logout_rounded, size: 20),
                label: Text(
                  ref.tr('logout'),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFEF4444),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 2,
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  void _showEditProfileDialog(
    BuildContext context,
    WidgetRef ref,
    User? user,
    String? currentPhotoUrl,
    String? currentPhoneNumber,
  ) {
    if (user == null) return;

    final phoneController =
        TextEditingController(text: currentPhoneNumber ?? '');
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();

    String? selectedPhotoUrl = currentPhotoUrl;
    bool photoRemoved = false;
    bool obscurePassword = true;
    bool obscureConfirmPassword = true;
    bool isLoading = false;
    String? errorMessage;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, dialogSetState) {
          final activePhotoUrl = photoRemoved ? null : selectedPhotoUrl;
          final avatarImage = getProfileImageProvider(activePhotoUrl);

          return AlertDialog(
            title: Text(ref.tr('editProfile')),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      ref.tr('profilePicture'),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  CircleAvatar(
                    radius: 46,
                    backgroundColor:
                        Theme.of(context).colorScheme.primaryContainer,
                    backgroundImage: avatarImage,
                    child: avatarImage == null
                        ? Icon(
                            Icons.person,
                            size: 46,
                            color: Theme.of(context).colorScheme.primary,
                          )
                        : null,
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: isLoading
                            ? null
                            : () async {
                                final picker = ImagePicker();
                                final pickedFile = await picker.pickImage(
                                  source: ImageSource.gallery,
                                  maxWidth: 512,
                                  maxHeight: 512,
                                  imageQuality: 75,
                                );
                                if (pickedFile != null) {
                                  final bytes = await pickedFile.readAsBytes();
                                  final base64Image =
                                      'data:image/png;base64,${base64Encode(bytes)}';
                                  dialogSetState(() {
                                    selectedPhotoUrl = base64Image;
                                    photoRemoved = false;
                                  });
                                }
                              },
                        icon: const Icon(Icons.photo_library, size: 18),
                        label: Text(ref.tr('gallery')),
                      ),
                      OutlinedButton.icon(
                        onPressed: isLoading
                            ? null
                            : () async {
                                final picker = ImagePicker();
                                final pickedFile = await picker.pickImage(
                                  source: ImageSource.camera,
                                  maxWidth: 512,
                                  maxHeight: 512,
                                  imageQuality: 75,
                                );
                                if (pickedFile != null) {
                                  final bytes = await pickedFile.readAsBytes();
                                  final base64Image =
                                      'data:image/png;base64,${base64Encode(bytes)}';
                                  dialogSetState(() {
                                    selectedPhotoUrl = base64Image;
                                    photoRemoved = false;
                                  });
                                }
                              },
                        icon: const Icon(Icons.camera_alt, size: 18),
                        label: Text(ref.tr('camera')),
                      ),
                      if (activePhotoUrl != null)
                        OutlinedButton.icon(
                          onPressed: isLoading
                              ? null
                              : () {
                                  dialogSetState(() {
                                    selectedPhotoUrl = null;
                                    photoRemoved = true;
                                  });
                                },
                          icon: const Icon(
                            Icons.delete_outline,
                            size: 18,
                            color: Colors.red,
                          ),
                          label: Text(
                            ref.tr('remove'),
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    enabled: !isLoading,
                    decoration: InputDecoration(
                      labelText: ref.tr('phoneNumber'),
                      hintText: ref.tr('phoneNumberHint'),
                      prefixIcon: const Icon(Icons.phone_outlined),
                    ),
                  ),
                  const Divider(height: 32),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      ref.tr('changePassword'),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      ref.tr('leaveBlankPassword'),
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: newPasswordController,
                    obscureText: obscurePassword,
                    enabled: !isLoading,
                    decoration: InputDecoration(
                      labelText: ref.tr('newPassword'),
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscurePassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                        onPressed: () => dialogSetState(
                          () => obscurePassword = !obscurePassword,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: confirmPasswordController,
                    obscureText: obscureConfirmPassword,
                    enabled: !isLoading,
                    decoration: InputDecoration(
                      labelText: ref.tr('confirmNewPassword'),
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscureConfirmPassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                        onPressed: () => dialogSetState(
                          () =>
                              obscureConfirmPassword = !obscureConfirmPassword,
                        ),
                      ),
                    ),
                  ),
                  if (errorMessage != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.error_outline,
                            color: Colors.red,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              errorMessage!,
                              style: const TextStyle(
                                color: Colors.red,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (isLoading) ...[
                    const SizedBox(height: 20),
                    const CircularProgressIndicator(),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isLoading ? null : () => Navigator.pop(ctx),
                child: Text(ref.tr('cancel')),
              ),
              FilledButton(
                onPressed: isLoading
                    ? null
                    : () async {
                        final newPassword = newPasswordController.text.trim();
                        final confirmPassword =
                            confirmPasswordController.text.trim();

                        if (newPassword.isNotEmpty) {
                          if (!RegExp(r'^\d+$').hasMatch(newPassword)) {
                            dialogSetState(
                              () =>
                                  errorMessage = ref.tr('passwordNumericOnly'),
                            );
                            return;
                          }
                          if (newPassword.length < 6) {
                            dialogSetState(
                              () => errorMessage = ref.tr('passwordMinLength'),
                            );
                            return;
                          }
                          if (newPassword != confirmPassword) {
                            dialogSetState(
                              () =>
                                  errorMessage = ref.tr('passwordsDoNotMatch'),
                            );
                            return;
                          }
                        }

                        dialogSetState(() {
                          isLoading = true;
                          errorMessage = null;
                        });

                        try {
                          if (photoRemoved) {
                            await FirebaseFirestore.instance
                                .collection('users')
                                .doc(user.uid)
                                .update({
                              'photoUrl': FieldValue.delete(),
                            });
                            await user.updatePhotoURL(null);
                          } else if (selectedPhotoUrl != null &&
                              selectedPhotoUrl != currentPhotoUrl) {
                            await FirebaseFirestore.instance
                                .collection('users')
                                .doc(user.uid)
                                .update({
                              'photoUrl': selectedPhotoUrl,
                            });
                            if (selectedPhotoUrl!.startsWith('http')) {
                              await user.updatePhotoURL(selectedPhotoUrl);
                            }
                          }

                          await FirebaseFirestore.instance
                              .collection('users')
                              .doc(user.uid)
                              .set(
                            {
                              'phoneNumber': phoneController.text.trim(),
                            },
                            SetOptions(merge: true),
                          );

                          if (newPassword.isNotEmpty) {
                            await user.updatePassword(newPassword);
                          }

                          if (context.mounted) {
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(ref.tr('profileUpdated')),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        } on FirebaseAuthException catch (e) {
                          dialogSetState(() {
                            isLoading = false;
                            if (e.code == 'requires-recent-login') {
                              errorMessage = ref.tr('requiresRecentLogin');
                            } else {
                              errorMessage =
                                  e.message ?? ref.tr('failedToUpdateProfile');
                            }
                          });
                        } catch (e) {
                          dialogSetState(() {
                            isLoading = false;
                            errorMessage =
                                '${ref.tr('failedToUpdateProfile')}: $e';
                          });
                        }
                      },
                child: Text(ref.tr('save')),
              ),
            ],
          );
        },
      ),
    );
  }
}
