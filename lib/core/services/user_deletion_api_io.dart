import 'dart:convert';
import 'dart:io';

import 'user_deletion_api_stub.dart';

Future<void> deleteUserThroughAdminApi({
  required String baseUrl,
  required String uid,
  required String idToken,
}) async {
  final client = HttpClient();
  try {
    final uri = Uri.parse(baseUrl).resolve('/users/$uid');
    final request = await client.deleteUrl(uri);
    request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $idToken');
    final response = await request.close();
    final body = await utf8.decodeStream(response);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw UserDeletionApiException(_messageFromBody(body));
    }
  } finally {
    client.close(force: true);
  }
}

Future<AdminUserLookupResult> lookupUserByEmailThroughAdminApi({
  required String baseUrl,
  required String email,
  required String idToken,
}) async {
  final client = HttpClient();
  try {
    final uri = Uri.parse(baseUrl).resolve(
      '/users/lookup-by-email/${Uri.encodeComponent(email)}',
    );
    final request = await client.getUrl(uri);
    request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $idToken');
    final response = await request.close();
    final body = await utf8.decodeStream(response);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw UserDeletionApiException(_messageFromBody(body));
    }

    final decoded = jsonDecode(body);
    if (decoded is! Map) {
      throw const UserDeletionApiException(
        'The admin user lookup API returned an invalid response.',
      );
    }

    final uid = decoded['uid'];
    return AdminUserLookupResult(
      uid: uid is String && uid.isNotEmpty ? uid : null,
      hasFirestoreProfile: decoded['hasFirestoreProfile'] == true,
    );
  } finally {
    client.close(force: true);
  }
}

String _messageFromBody(String body) {
  if (body.trim().isEmpty) return 'The user deletion API rejected the request.';
  final decoded = jsonDecode(body);
  if (decoded is Map && decoded['message'] is String) {
    return decoded['message'] as String;
  }
  return 'The user deletion API rejected the request.';
}
