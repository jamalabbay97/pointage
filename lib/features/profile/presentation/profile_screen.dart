import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
                  CircleAvatar(
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
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.verified,
                        color: Colors.white,
                        size: 20,
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
                  label: Text(
                    ref.trRole(userModel?.role ?? 'employee').toUpperCase(),
                  ),
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
                    Text(
                      ref.tr('accountInfo'),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const Divider(height: 24),
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
                        user?.providerData.firstOrNull?.providerId ??
                            'password',
                      ),
                    ),
                    _buildProfileRow(
                      ref.tr('phoneNumber'),
                      userModel?.phoneNumber ?? 'N/A',
                    ),
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
                label: Text(ref.tr('logout')),
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
                              () => errorMessage = ref.tr('passwordNumericOnly'),
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
