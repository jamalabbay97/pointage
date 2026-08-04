import 'dart:convert';

import 'package:http/browser_client.dart';

import 'user_deletion_api_stub.dart';

Future<void> deleteUserThroughAdminApi({
  required String baseUrl,
  required String uid,
  required String idToken,
}) async {
  final client = BrowserClient();
  try {
    final uri = Uri.parse(baseUrl).resolve('/users/$uid');
    final response = await client.delete(
      uri,
      headers: {'Authorization': 'Bearer $idToken'},
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw UserDeletionApiException(_messageFromBody(response.body));
    }
  } finally {
    client.close();
  }
}

String _messageFromBody(String body) {
  if (body.trim().isEmpty) {
    return 'The user deletion API rejected the request.';
  }
  final decoded = jsonDecode(body);
  if (decoded is Map && decoded['message'] is String) {
    return decoded['message'] as String;
  }
  return 'The user deletion API rejected the request.';
}
