import 'dart:convert';
import 'dart:html' as html;

import 'user_deletion_api_stub.dart';

Future<void> deleteUserThroughAdminApi({
  required String baseUrl,
  required String uid,
  required String idToken,
}) async {
  final uri = Uri.parse(baseUrl).resolve('/users/$uid').toString();
  final response = await html.HttpRequest.request(
    uri,
    method: 'DELETE',
    requestHeaders: {'Authorization': 'Bearer $idToken'},
  );

  final status = response.status ?? 0;
  if (status < 200 || status >= 300) {
    throw UserDeletionApiException(_messageFromBody(response.responseText));
  }
}

String _messageFromBody(String? body) {
  if (body == null || body.trim().isEmpty) {
    return 'The user deletion API rejected the request.';
  }
  final decoded = jsonDecode(body);
  if (decoded is Map && decoded['message'] is String) {
    return decoded['message'] as String;
  }
  return 'The user deletion API rejected the request.';
}
