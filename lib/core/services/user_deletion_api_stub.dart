class UserDeletionApiException implements Exception {
  const UserDeletionApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AdminUserLookupResult {
  const AdminUserLookupResult({
    required this.uid,
    required this.hasFirestoreProfile,
  });

  final String? uid;
  final bool hasFirestoreProfile;
}

Future<void> deleteUserThroughAdminApi({
  required String baseUrl,
  required String uid,
  required String idToken,
}) async {
  throw const UserDeletionApiException(
    'This platform cannot call the user deletion API.',
  );
}

Future<AdminUserLookupResult> lookupUserByEmailThroughAdminApi({
  required String baseUrl,
  required String email,
  required String idToken,
}) async {
  throw const UserDeletionApiException(
    'This platform cannot call the admin user API.',
  );
}
