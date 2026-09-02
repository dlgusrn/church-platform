import 'package:flutter/services.dart';

abstract interface class TokenStore {
  Future<String?> readAccessToken();
  Future<String?> readRefreshToken();
  Future<void> writeTokens({
    required String accessToken,
    required String refreshToken,
  });
  Future<void> clear();
}

class PlatformSecureTokenStore implements TokenStore {
  static const _channel = MethodChannel('church_app/secure_storage');
  static const _accessKey = 'access_token';
  static const _refreshKey = 'refresh_token';

  @override
  Future<String?> readAccessToken() => _read(_accessKey);

  @override
  Future<String?> readRefreshToken() => _read(_refreshKey);

  Future<String?> _read(String key) =>
      _channel.invokeMethod<String>('read', {'key': key});

  @override
  Future<void> writeTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _channel.invokeMethod<void>('write', {
      'key': _accessKey,
      'value': accessToken,
    });
    await _channel.invokeMethod<void>('write', {
      'key': _refreshKey,
      'value': refreshToken,
    });
  }

  @override
  Future<void> clear() => _channel.invokeMethod<void>('deleteAll');
}

class MemoryTokenStore implements TokenStore {
  String? accessToken;
  String? refreshToken;

  @override
  Future<String?> readAccessToken() async => accessToken;

  @override
  Future<String?> readRefreshToken() async => refreshToken;

  @override
  Future<void> writeTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    this.accessToken = accessToken;
    this.refreshToken = refreshToken;
  }

  @override
  Future<void> clear() async {
    accessToken = null;
    refreshToken = null;
  }
}
