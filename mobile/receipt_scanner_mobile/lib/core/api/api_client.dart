import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiClient {
  final http.Client client;
  final Future<String?> Function() tokenProvider;

  ApiClient({required this.client, required this.tokenProvider});

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
