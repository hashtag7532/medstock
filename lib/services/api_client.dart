import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

/// Calls the MedStock server with the signed-in user's Firebase ID token.
class ApiClient {
  ApiClient(this.baseUrl, this._idToken, {http.Client? client}) : _client = client ?? http.Client();

  final String baseUrl;
  final Future<String?> Function() _idToken;
  final http.Client _client;

  Future<Map<String, dynamic>> post(String path, Map<String, Object?> body) => _send('POST', path, body);

  Future<Map<String, dynamic>> get(String path) => _send('GET', path, null);

  Future<Map<String, dynamic>> _send(String method, String path, Map<String, Object?>? body) async {
    final token = await _idToken();
    if (token == null) throw const ApiException(401, 'Not signed in');
    final request = http.Request(method, Uri.parse('$baseUrl$path'))
      ..headers['authorization'] = 'Bearer $token'
      ..headers['content-type'] = 'application/json';
    if (body != null) request.body = jsonEncode(body);
    final http.Response response;
    try {
      response = await http.Response.fromStream(await _client.send(request).timeout(const Duration(seconds: 30)));
    } on SocketException {
      throw const ApiException(0, 'Can\'t reach the server');
    }
    final text = utf8.decode(response.bodyBytes);
    if (response.statusCode != 200) throw ApiException(response.statusCode, text);
    return jsonDecode(text) as Map<String, dynamic>;
  }
}

class ApiException implements Exception {
  const ApiException(this.status, this.message);

  /// HTTP status, or 0 when the server couldn't be reached.
  final int status;
  final String message;

  @override
  String toString() => status == 0 ? message : 'Server error $status: $message';
}
