import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiClient {
  final http.Client client;
  final Future<String?> Function() tokenProvider;

  ApiClient({required this.client, required this.tokenProvider});

  Future<Map<String, String>> _getHeaders() async {
    final token = await tokenProvider();
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  Future<http.Response> get({required Uri uri}) async {
    final headers = await _getHeaders();
    return client.get(uri, headers: headers);
  }

  Future<http.Response> post({
    required Uri uri,
    Map<String, dynamic>? body,
  }) async {
    final headers = await _getHeaders();
    return client.post(
      uri,
      headers: headers,
      body: body != null ? jsonEncode(body) : null,
    );
  }

  Future<http.Response> patch({
    required Uri uri,
    Map<String, dynamic>? body,
  }) async {
    final headers = await _getHeaders();
    return client.patch(
      uri,
      headers: headers,
      body: body != null ? jsonEncode(body) : null,
    );
  }

  Future<http.Response> delete({required Uri uri}) async {
    final headers = await _getHeaders();
    return client.delete(uri, headers: headers);
  }

  Future<http.Response> postMultipart({
    required Uri uri,
    required String fieldName,
    required List<int> fileBytes,
    required String filename,
  }) async {
    final request = http.MultipartRequest('POST', uri);
    final token = await tokenProvider();
    if (token != null && token.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer $token';
    }
    request.files.add(
      http.MultipartFile.fromBytes(fieldName, fileBytes, filename: filename),
    );

    final streamed = await request.send();
    return http.Response(
      await streamed.stream.bytesToString(),
      streamed.statusCode,
      headers: streamed.headers,
    );
  }

  Map<String, dynamic> parseJsonObject(String body) {
    if (body.trim().isEmpty) {
      return {};
    }
    return jsonDecode(body) as Map<String, dynamic>;
  }
}
