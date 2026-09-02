class ApiConfig {
  const ApiConfig._();

  static const baseUrl = String.fromEnvironment('API_BASE_URL');
  static const useMockRepositories = bool.fromEnvironment(
    'USE_MOCK_REPOSITORIES',
  );

  static Uri requireBaseUri() {
    final value = baseUrl.trim();
    if (value.isEmpty) {
      throw const ApiConfigurationException(
        'API 주소가 설정되지 않았습니다. '
        '--dart-define=API_BASE_URL=http://<MAC_LAN_IP>:8000 으로 실행해주세요.',
      );
    }
    final uri = Uri.tryParse(value);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      throw const ApiConfigurationException('API_BASE_URL 형식이 올바르지 않습니다.');
    }
    return uri;
  }
}

class ApiConfigurationException implements Exception {
  const ApiConfigurationException(this.message);
  final String message;
}
