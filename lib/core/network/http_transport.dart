import 'http_transport_stub.dart'
    if (dart.library.io) 'http_transport_io.dart'
    as platform;

abstract interface class HttpTransport {
  Future<HttpTransportResponse> send({
    required String method,
    required Uri uri,
    required Map<String, String> headers,
    List<int>? bodyBytes,
  });

  void close();
}

class HttpTransportResponse {
  const HttpTransportResponse({required this.statusCode, required this.body});
  final int statusCode;
  final String body;
}

HttpTransport createPlatformHttpTransport() =>
    platform.createPlatformHttpTransport();
