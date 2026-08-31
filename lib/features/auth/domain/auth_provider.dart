import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
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
      .map<UserModel?>((snapshot) {
    if (!snapshot.exists || snapshot.data() == null) {
      // Fallback if doc doesn't exist yet in Firestore
      return UserModel(
        uid: authUser.uid,
        email: authUser.email ?? '',
        displayName: authUser.displayName ?? (authUser.email?.split('@').first ?? 'User'),
        role: 'employee',
        status: 'active',
        department: 'General',
      );
    }
    return UserModel.fromJson(snapshot.data()!, snapshot.id);
  }).handleError((error, stackTrace) {
    debugPrint('Error fetching user doc: $error');
    return UserModel(
      uid: authUser.uid,
      email: authUser.email ?? '',
      displayName: authUser.displayName ?? (authUser.email?.split('@').first ?? 'User'),
      role: 'employee',
      status: 'active',
      department: 'General',
    );
  });
});

final isAdminOrManagerProvider = Provider<bool>((ref) {
  final userModel = ref.watch(currentUserModelProvider).valueOrNull;
  return userModel?.isAdminOrManager ?? false;
});
