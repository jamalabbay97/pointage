class UserDeletionApiException implements Exception {
  const UserDeletionApiException(this.message);

  final String message;

  @override
  String toString() => message;
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
