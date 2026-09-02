import 'dart:convert';

import 'package:church_app/core/auth/api_auth_repository.dart';
import 'package:church_app/core/auth/auth_repository.dart';
import 'package:church_app/core/network/api_client.dart';
import 'package:church_app/core/network/api_model_mapper.dart';
import 'package:church_app/core/network/http_transport.dart';
import 'package:church_app/core/network/token_store.dart';
import 'package:church_app/core/permission/app_permission.dart';
import 'package:church_app/core/permission/app_role.dart';
import 'package:church_app/features/church/data/api_church_repository.dart';
import 'package:church_app/features/church/data/api_membership_repository.dart';
import 'package:church_app/features/church/data/membership_repository.dart';
import 'package:church_app/features/home/data/api_home_repository.dart';
import 'package:church_app/features/home/domain/home_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('한글이 포함된 JSON request body를 UTF-8 bytes로 전송한다', () async {
    final transport = FakeHttpTransport([
      jsonResponse(201, {'id': 1}),
    ]);
    final client = apiClient(transport, MemoryTokenStore());

    await client.request(
      'POST',
      '/api/v1/auth/register',
      authenticated: false,
      body: const {
        'name': '이현구 Test',
        'email': 'hyungu@example.com',
        'password': 'password123',
      },
    );

    final request = transport.requests.single;
    final decoded = jsonDecode(utf8.decode(request.bodyBytes!));
    expect(request.uri.toString(), 'http://api.test:8000/api/v1/auth/register');
    expect(request.headers['Content-Type'], 'application/json; charset=utf-8');
    expect(decoded['name'], '이현구 Test');
    expect(decoded['email'], 'hyungu@example.com');
  });

  test('예배 일정과 current LIVE 응답을 파싱하고 Backend 제목을 그대로 사용한다', () async {
    final transport = FakeHttpTransport([
      jsonResponse(200, [worshipScheduleJson]),
      jsonResponse(200, liveBroadcastJson),
    ]);
    final repository = ApiHomeRepository(
      apiClient(transport, MemoryTokenStore()..accessToken = 'access'),
    );

    final content = await repository.getHomeContent('1');

    expect(content.schedules.single.name, '낮예배');
    expect(content.schedules.single.displayTime, '11:00');
    expect(content.live?.displayTitle, '서버가 만든 정확한 제목');
    expect(content.live?.status, LiveBroadcastStatus.live);
    expect(transport.requests.map((item) => item.uri.path), [
      '/api/v1/churches/1/worship-schedules',
      '/api/v1/churches/1/live-broadcasts/current',
    ]);
  });

  test('current LIVE null과 빈 예배 일정 응답을 empty state로 매핑한다', () async {
    final repository = ApiHomeRepository(
      apiClient(
        FakeHttpTransport([
          jsonResponse(200, const []),
          const HttpTransportResponse(statusCode: 200, body: 'null'),
        ]),
        MemoryTokenStore()..accessToken = 'access',
      ),
    );

    final content = await repository.getHomeContent('1');
    expect(content.live, isNull);
    expect(content.schedules, isEmpty);
  });

  test('401이면 refresh rotation 후 원 요청을 새 access token으로 재시도한다', () async {
    final store = MemoryTokenStore()
      ..accessToken = 'expired-access'
      ..refreshToken = 'refresh-one';
    final transport = FakeHttpTransport([
      jsonResponse(401, {'detail': 'expired'}),
      jsonResponse(200, {
        'access_token': 'access-two',
        'refresh_token': 'refresh-two',
        'token_type': 'bearer',
      }),
      jsonResponse(200, {'id': 1}),
    ]);
    final client = apiClient(transport, store);

    expect(await client.get('/api/v1/users/me'), {'id': 1});
    expect(
      transport.requests[0].headers['Authorization'],
      'Bearer expired-access',
    );
    expect(transport.requests[1].uri.path, '/api/v1/auth/refresh');
    expect(transport.requests[2].headers['Authorization'], 'Bearer access-two');
    expect(store.refreshToken, 'refresh-two');
  });

  test('refresh 실패 시 token을 삭제하고 session expired callback을 호출한다', () async {
    final store = MemoryTokenStore()
      ..accessToken = 'expired'
      ..refreshToken = 'invalid-refresh';
    final transport = FakeHttpTransport([
      jsonResponse(401, {'detail': 'expired'}),
      jsonResponse(401, {'detail': 'invalid refresh'}),
    ]);
    final client = apiClient(transport, store);
    var expired = false;
    client.onSessionExpired = () => expired = true;

    await expectLater(
      client.get('/api/v1/users/me'),
      throwsA(isA<SessionExpiredException>()),
    );
    expect(expired, isTrue);
    expect(store.accessToken, isNull);
    expect(store.refreshToken, isNull);
  });

  test('실제 login 계약으로 token 저장 후 user와 membership을 구성한다', () async {
    final store = MemoryTokenStore();
    final transport = FakeHttpTransport([
      tokenResponse,
      jsonResponse(200, userJson),
      jsonResponse(200, [approvedMembershipJson]),
    ]);
    final repository = ApiAuthRepository(apiClient(transport, store));

    final user = await repository.signIn(
      loginId: 'member@example.com',
      password: 'password123',
    );

    expect(user.email, 'member@example.com');
    expect(
      transport.requests.first.uri.toString(),
      'http://api.test:8000/api/v1/auth/login',
    );
    expect(user.memberships.single.effectivePermissions, {
      AppPermission.liveAccess,
      AppPermission.vodView,
    });
    expect(store.accessToken, 'access');
    expect(
      jsonDecode(transport.requests.first.body!)['identifier'],
      'member@example.com',
    );
  });

  test('login 401은 refresh 없이 사용자 인증 오류로 전달한다', () async {
    final transport = FakeHttpTransport([
      jsonResponse(401, {'detail': 'Invalid credentials'}),
    ]);
    final repository = ApiAuthRepository(
      apiClient(transport, MemoryTokenStore()),
    );

    await expectLater(
      repository.signIn(loginId: 'missing@example.com', password: 'wrong'),
      throwsA(
        isA<AuthException>().having(
          (error) => error.message,
          'message',
          '아이디 또는 비밀번호를 확인해주세요.',
        ),
      ),
    );
    expect(transport.requests, hasLength(1));
  });

  test('register 성공 후 동일 자격정보로 login하여 세션을 만든다', () async {
    final transport = FakeHttpTransport([
      jsonResponse(201, userJson),
      tokenResponse,
      jsonResponse(200, userJson),
      jsonResponse(200, const []),
    ]);
    final store = MemoryTokenStore();
    final repository = ApiAuthRepository(apiClient(transport, store));

    final user = await repository.register(
      const RegisterRequest(
        name: '성도',
        loginId: 'member@example.com',
        password: 'password123',
      ),
    );

    expect(user.id, '7');
    expect(
      transport.requests.first.uri.toString(),
      'http://api.test:8000/api/v1/auth/register',
    );
    expect(transport.requests.map((item) => item.uri.path), [
      '/api/v1/auth/register',
      '/api/v1/auth/login',
      '/api/v1/users/me',
      '/api/v1/users/me/memberships',
    ]);
    expect(store.refreshToken, 'refresh');
  });

  test('token store는 access와 refresh를 함께 저장하고 로그아웃 시 비운다', () async {
    final store = MemoryTokenStore();
    await store.writeTokens(accessToken: 'access', refreshToken: 'refresh');
    expect(await store.readAccessToken(), 'access');
    expect(await store.readRefreshToken(), 'refresh');
    await store.clear();
    expect(await store.readAccessToken(), isNull);
    expect(await store.readRefreshToken(), isNull);
  });

  test('저장 token으로 session을 복원한다', () async {
    final store = MemoryTokenStore()
      ..accessToken = 'access'
      ..refreshToken = 'refresh';
    final repository = ApiAuthRepository(
      apiClient(
        FakeHttpTransport([
          jsonResponse(200, userJson),
          jsonResponse(200, [approvedMembershipJson]),
        ]),
        store,
      ),
    );

    final user = await repository.restoreSession();
    expect(user?.approvedMemberships, hasLength(1));
  });

  test('register 409 오류를 사용자 인증 오류로 전달한다', () async {
    final repository = ApiAuthRepository(
      apiClient(
        FakeHttpTransport([
          jsonResponse(409, {'detail': 'Email is already registered'}),
        ]),
        MemoryTokenStore(),
      ),
    );

    await expectLater(
      repository.register(
        const RegisterRequest(
          name: '중복',
          loginId: 'member@example.com',
          password: 'password123',
        ),
      ),
      throwsA(
        isA<AuthException>().having(
          (error) => error.message,
          'message',
          '이미 가입된 이메일입니다.',
        ),
      ),
    );
  });

  test('church와 pending membership API 응답을 정확히 매핑한다', () async {
    final transport = FakeHttpTransport([
      jsonResponse(200, [
        {'id': 1, 'code': 'skygate', 'name': '하늘문교회'},
        {'id': 2, 'code': 'beer', 'name': '브엘성회'},
      ]),
      jsonResponse(200, [pendingMembershipJson]),
    ]);
    final client = apiClient(
      transport,
      MemoryTokenStore()..accessToken = 'access',
    );

    final churches = await ApiChurchRepository(client).getChurches();
    final pending = await ApiMembershipRepository(client)
        .getPendingMemberships(churchId: '1');

    expect(churches.map((item) => item.code), ['skygate', 'beer']);
    expect(pending.single.applicantName, '가입자');
    expect(pending.single.effectivePermissions, isEmpty);
  });

  test('가입 신청 pending 응답과 중복 409를 처리한다', () async {
    final transport = FakeHttpTransport([
      jsonResponse(201, {
        ...pendingMembershipJson,
        'user': null,
        'role': null,
        'approved_at': null,
        'effective_permissions': const [],
      }),
      jsonResponse(409, {'detail': 'Membership already exists'}),
    ]);
    final repository = ApiMembershipRepository(
      apiClient(transport, MemoryTokenStore()..accessToken = 'access'),
    );

    final membership = await repository.requestJoin(userId: '7', churchId: '1');
    expect(membership.status.name, 'pending');
    await expectLater(
      repository.requestJoin(userId: '7', churchId: '1'),
      throwsA(
        isA<MembershipException>().having(
          (error) => error.message,
          'message',
          '이미 가입했거나 가입 신청 중인 교회입니다.',
        ),
      ),
    );
  });

  test('permission 상세에서 deny와 unknown code를 안전하게 처리한다', () {
    final breakdown = ApiModelMapper.permissionBreakdown({
      'role_permissions': ['live.access', 'vod.view'],
      'granted_permissions': ['media.audio.view', 'future.permission'],
      'denied_permissions': ['vod.view'],
      'effective_permissions': ['live.access', 'media.audio.view'],
    });

    expect(breakdown.grantedPermissions, {AppPermission.mediaAudioView});
    expect(breakdown.deniedPermissions, {AppPermission.vodView});
    expect(breakdown.effectivePermissions, {
      AppPermission.liveAccess,
      AppPermission.mediaAudioView,
    });
  });

  test('approve reject permission update가 Backend 계약 경로와 body를 사용한다', () async {
    final transport = FakeHttpTransport([
      jsonResponse(200, approvedMembershipJson),
      jsonResponse(200, {...approvedMembershipJson, 'status': 'rejected'}),
      jsonResponse(200, approvedMembershipJson),
    ]);
    final repository = ApiMembershipRepository(
      apiClient(transport, MemoryTokenStore()..accessToken = 'access'),
    );
    const role = AppRole(
      id: '2',
      code: 'member',
      name: '성도',
      defaultPermissions: {AppPermission.liveAccess, AppPermission.vodView},
    );

    await repository.approve(
      churchId: '1',
      membershipId: '10',
      role: role,
      addedPermissions: {AppPermission.mediaAudioView},
      excludedPermissions: {AppPermission.vodView},
    );
    await repository.reject(churchId: '1', membershipId: '10');
    await repository.updatePermissions(
      churchId: '1',
      membershipId: '10',
      role: role,
    );

    expect(
      transport.requests[0].uri.path,
      '/api/v1/churches/1/memberships/10/approve',
    );
    expect(jsonDecode(transport.requests[0].body!)['denied_permissions'], [
      'vod.view',
    ]);
    expect(
      transport.requests[1].uri.path,
      '/api/v1/churches/1/memberships/10/reject',
    );
    expect(transport.requests[2].method, 'PATCH');
  });

  test('관리 API 403은 MembershipException으로 노출한다', () async {
    final repository = ApiMembershipRepository(
      apiClient(
        FakeHttpTransport([
          jsonResponse(403, {'detail': 'Missing permission: member.view'}),
        ]),
        MemoryTokenStore()..accessToken = 'access',
      ),
    );

    await expectLater(
      repository.getPendingMemberships(churchId: '2'),
      throwsA(isA<MembershipException>()),
    );
  });
}

ApiClient apiClient(FakeHttpTransport transport, MemoryTokenStore store) =>
    ApiClient(
      baseUri: Uri.parse('http://api.test:8000'),
      transport: transport,
      tokenStore: store,
    );

const userJson = {
  'id': 7,
  'name': '성도',
  'email': 'member@example.com',
  'phone': null,
  'email_verified_at': null,
  'phone_verified_at': null,
  'is_active': true,
  'created_at': '2026-09-01T00:00:00Z',
  'updated_at': '2026-09-01T00:00:00Z',
  'last_login_at': null,
};

const approvedMembershipJson = {
  'membership_id': 10,
  'church': {'id': 1, 'code': 'skygate', 'name': '하늘문교회'},
  'status': 'approved',
  'role': {'id': 2, 'code': 'member', 'name': '성도', 'is_system': true},
  'requested_at': '2026-09-01T00:00:00Z',
  'approved_at': '2026-09-01T01:00:00Z',
  'effective_permissions': ['live.access', 'vod.view'],
};

const pendingMembershipJson = {
  'membership_id': 11,
  'user': {'id': 8, 'name': '가입자', 'email': 'join@example.com', 'phone': null},
  'church': {'id': 1, 'code': 'skygate', 'name': '하늘문교회'},
  'status': 'pending',
  'requested_at': '2026-09-01T00:00:00Z',
};

const worshipScheduleJson = {
  'id': 21,
  'church_id': 1,
  'title': '낮예배',
  'day_label': '수요일',
  'time': '11:00:00',
  'display_order': 1,
  'is_active': true,
  'created_at': '2026-09-02T00:00:00Z',
  'updated_at': '2026-09-02T00:00:00Z',
};

const liveBroadcastJson = {
  'id': 31,
  'church_id': 1,
  'worship_type': 'day',
  'custom_worship_name': null,
  'broadcast_date': '2026-09-02',
  'title_override': null,
  'display_title': '서버가 만든 정확한 제목',
  'youtube_url': 'https://youtu.be/example',
  'status': 'live',
  'started_at': '2026-09-02T01:00:00Z',
  'ended_at': null,
  'created_at': '2026-09-02T00:00:00Z',
  'updated_at': '2026-09-02T00:00:00Z',
};

final tokenResponse = jsonResponse(200, {
  'access_token': 'access',
  'refresh_token': 'refresh',
  'token_type': 'bearer',
});

HttpTransportResponse jsonResponse(int statusCode, Object body) =>
    HttpTransportResponse(statusCode: statusCode, body: jsonEncode(body));

class RecordedRequest {
  const RecordedRequest({
    required this.method,
    required this.uri,
    required this.headers,
    required this.bodyBytes,
  });
  final String method;
  final Uri uri;
  final Map<String, String> headers;
  final List<int>? bodyBytes;

  String? get body => bodyBytes == null ? null : utf8.decode(bodyBytes!);
}

class FakeHttpTransport implements HttpTransport {
  FakeHttpTransport(this.responses);
  final List<HttpTransportResponse> responses;
  final List<RecordedRequest> requests = [];

  @override
  Future<HttpTransportResponse> send({
    required String method,
    required Uri uri,
    required Map<String, String> headers,
    List<int>? bodyBytes,
  }) async {
    requests.add(
      RecordedRequest(
        method: method,
        uri: uri,
        headers: Map.unmodifiable(headers),
        bodyBytes: bodyBytes == null ? null : List.unmodifiable(bodyBytes),
      ),
    );
    if (responses.isEmpty) throw StateError('No fake response queued');
    return responses.removeAt(0);
  }

  @override
  void close() {}
}
