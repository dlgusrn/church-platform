import 'dart:convert';
import 'dart:io';

import 'http_transport.dart';

HttpTransport createPlatformHttpTransport() => IoHttpTransport();

class IoHttpTransport implements HttpTransport {
  IoHttpTransport({HttpClient? client}) : _client = client ?? HttpClient();

  final HttpClient _client;

  @override
  Future<HttpTransportResponse> send({
    required String method,
    required Uri uri,
    required Map<String, String> headers,
    List<int>? bodyBytes,
  }) async {
    final request = await _client.openUrl(method, uri);
    headers.forEach(request.headers.set);
    if (bodyBytes != null) request.add(bodyBytes);
    final response = await request.close();
    return HttpTransportResponse(
      statusCode: response.statusCode,
      body: await utf8.decoder.bind(response).join(),
    );
  }

  @override
  void close() => _client.close(force: true);
}
