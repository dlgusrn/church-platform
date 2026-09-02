import 'http_transport.dart';

HttpTransport createPlatformHttpTransport() => _UnsupportedTransport();

class _UnsupportedTransport implements HttpTransport {
  @override
  Future<HttpTransportResponse> send({
    required String method,
    required Uri uri,
    required Map<String, String> headers,
    List<int>? bodyBytes,
  }) => throw UnsupportedError('이 플랫폼의 HTTP transport가 아직 구성되지 않았습니다.');

  @override
  void close() {}
}
