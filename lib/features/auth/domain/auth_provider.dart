import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/user_model.dart';

final authStateProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

final currentUserModelProvider = StreamProvider<UserModel?>((ref) {
  final authUser = ref.watch(authStateProvider).valueOrNull;
  if (authUser == null) return Stream.value(null);

  return FirebaseFirestore.instance
      .collection('users')
      .doc(authUser.uid)
      .snapshots()
      .map((snapshot) {
    if (!snapshot.exists || snapshot.data() == null) {
      // Fallback if doc doesn't exist yet in Firestore
      return UserModel(
        uid: authUser.uid,
        email: authUser.email ?? '',
        displayName: authUser.displayName ?? (authUser.email?.split('@').first ?? 'User'),
        role: authUser.email?.contains('admin') == true ? 'admin' : 'employee',
        status: 'active',
        department: 'General',
      );
    }
    return UserModel.fromJson(snapshot.data()!, snapshot.id);
  });
});

final isAdminOrManagerProvider = Provider<bool>((ref) {
  final userModel = ref.watch(currentUserModelProvider).valueOrNull;
  return userModel?.isAdminOrManager ?? false;
});
