import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'api_config.dart';
import 'http_transport.dart';
import 'token_store.dart';

typedef SessionExpiredCallback = FutureOr<void> Function();

class ApiClient {
  ApiClient({
    required this.baseUri,
    required this.transport,
    required this.tokenStore,
  });

  final Uri baseUri;
  final HttpTransport transport;
  final TokenStore tokenStore;
  SessionExpiredCallback? onSessionExpired;
  Future<bool>? _refreshOperation;

  Future<dynamic> get(String path) => request('GET', path);
  Future<dynamic> post(String path, {Map<String, dynamic>? body}) =>
      request('POST', path, body: body);
  Future<dynamic> patch(String path, {Map<String, dynamic>? body}) =>
      request('PATCH', path, body: body);
  Future<dynamic> delete(String path) => request('DELETE', path);

  Future<dynamic> request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    bool authenticated = true,
    bool retryAfterRefresh = true,
  }) async {
    Uri? requestUri;
    try {
      requestUri = _resolve(path);
      _debugLog('[API] $method $requestUri');
      final token = authenticated ? await tokenStore.readAccessToken() : null;
      final response = await transport.send(
        method: method,
        uri: requestUri,
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json; charset=utf-8',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        bodyBytes: body == null ? null : utf8.encode(jsonEncode(body)),
      );
      _debugLog('[API] $method $requestUri -> ${response.statusCode}');
      if (response.statusCode == 401 && authenticated && retryAfterRefresh) {
        if (await _refresh()) {
          return await request(
            method,
            path,
            body: body,
            authenticated: true,
            retryAfterRefresh: false,
          );
        }
        await _expireSession();
      }
      final decoded = _decode(response.body);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ApiException(
          statusCode: response.statusCode,
          message: _errorMessage(decoded, response.statusCode),
          details: decoded,
        );
      }
      return decoded;
    } on ApiException catch (error) {
      _debugLog(
        '[API ERROR] $method ${requestUri ?? path} '
        'ApiException(status=${error.statusCode}): ${error.message}',
      );
      rethrow;
    } on ApiConfigurationException catch (error) {
      _debugLog(
        '[API ERROR] $method ${requestUri ?? path} '
        'ApiConfigurationException: ${error.message}',
      );
      rethrow;
    } catch (error) {
      _debugLog(
        '[API ERROR] $method ${requestUri ?? path} '
        '${error.runtimeType}: $error',
      );
      throw ApiException(
        statusCode: 0,
        message: '서버에 연결할 수 없습니다. 네트워크와 API 주소를 확인해주세요.',
        details: error,
      );
    }
  }

  Future<void> saveTokens(dynamic json) async {
    final map = _map(json);
    final access = map['access_token'];
    final refresh = map['refresh_token'];
    if (access is! String || refresh is! String) {
      throw const ApiException(statusCode: 0, message: '인증 응답 형식이 올바르지 않습니다.');
    }
    await tokenStore.writeTokens(accessToken: access, refreshToken: refresh);
  }

  Future<bool> _refresh() {
    final existing = _refreshOperation;
    if (existing != null) return existing;
    final operation = _performRefresh();
    _refreshOperation = operation;
    return operation.whenComplete(() => _refreshOperation = null);
  }

  Future<bool> _performRefresh() async {
    final refreshToken = await tokenStore.readRefreshToken();
    if (refreshToken == null) return false;
    final uri = _resolve('/api/v1/auth/refresh');
    try {
      _debugLog('[API] POST $uri');
      final response = await transport.send(
        method: 'POST',
        uri: uri,
        headers: const {
          'Accept': 'application/json',
          'Content-Type': 'application/json; charset=utf-8',
        },
        bodyBytes: utf8.encode(jsonEncode({'refresh_token': refreshToken})),
      );
      _debugLog('[API] POST $uri -> ${response.statusCode}');
      if (response.statusCode < 200 || response.statusCode >= 300) return false;
      await saveTokens(_decode(response.body));
      return true;
    } catch (error) {
      _debugLog('[API ERROR] POST $uri ${error.runtimeType}: $error');
      return false;
    }
  }

  Future<void> _expireSession() async {
    await tokenStore.clear();
    await onSessionExpired?.call();
    throw const SessionExpiredException();
  }

  Uri _resolve(String path) {
    if (baseUri.host.isEmpty) {
      throw const ApiConfigurationException('API_BASE_URL이 설정되지 않았습니다.');
    }
    return baseUri.resolve(path);
  }

  static void _debugLog(String message) {
    if (kDebugMode) debugPrint(message);
  }

  static dynamic _decode(String body) {
    if (body.trim().isEmpty) return null;
    try {
      return jsonDecode(body);
    } catch (_) {
      return body;
    }
  }

  static Map<String, dynamic> _map(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return value.cast<String, dynamic>();
    throw const ApiException(statusCode: 0, message: '서버 응답 형식이 올바르지 않습니다.');
  }

  static String _errorMessage(dynamic body, int statusCode) {
    if (body is Map) {
      final detail = body['detail'];
      if (detail is String) return _localizedDetail(detail);
      if (detail is List) {
        return detail
            .whereType<Map>()
            .map((item) => item['msg'])
            .whereType<String>()
            .join('\n');
      }
    }
    return switch (statusCode) {
      401 => '로그인이 만료되었거나 인증 정보가 올바르지 않습니다.',
      403 => '이 작업을 수행할 권한이 없습니다.',
      404 => '요청한 정보를 찾을 수 없습니다.',
      409 => '이미 처리되었거나 중복된 요청입니다.',
      422 => '입력 내용을 확인해주세요.',
      _ when statusCode >= 500 => '서버 오류가 발생했습니다. 잠시 후 다시 시도해주세요.',
      _ => '요청을 처리하지 못했습니다.',
    };
  }

  static String _localizedDetail(String detail) => switch (detail) {
    'Invalid credentials' => '아이디 또는 비밀번호를 확인해주세요.',
    'Invalid access token' ||
    'Invalid refresh token' => '로그인 세션이 만료되었습니다. 다시 로그인해주세요.',
    'Email is already registered' => '이미 가입된 이메일입니다.',
    'Phone is already registered' => '이미 가입된 휴대전화 번호입니다.',
    'Email or phone is already registered' => '이미 가입된 이메일 또는 휴대전화 번호입니다.',
    'Membership already exists' => '이미 가입했거나 가입 신청 중인 교회입니다.',
    'Insufficient church permission' => '이 교회에서 해당 작업을 수행할 권한이 없습니다.',
    'Church not found' => '교회를 찾을 수 없습니다.',
    'Membership not found' => '가입 정보를 찾을 수 없습니다.',
    'Role not found' => '선택한 Role을 찾을 수 없습니다.',
    _ => detail,
  };
}

class ApiException implements Exception {
  const ApiException({
    required this.statusCode,
    required this.message,
    this.details,
  });
  final int statusCode;
  final String message;
  final Object? details;
}

class SessionExpiredException extends ApiException {
  const SessionExpiredException()
    : super(statusCode: 401, message: '로그인 세션이 만료되었습니다. 다시 로그인해주세요.');
}
