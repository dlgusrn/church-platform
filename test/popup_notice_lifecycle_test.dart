import 'dart:async';
import 'dart:convert';

import 'package:church_app/app/app_state.dart';
import 'package:church_app/app/app_scope.dart';
import 'package:church_app/core/auth/mock_auth_repository.dart';
import 'package:church_app/core/mock/mock_app_data_store.dart';
import 'package:church_app/core/network/api_client.dart';
import 'package:church_app/core/network/http_transport.dart';
import 'package:church_app/core/network/token_store.dart';
import 'package:church_app/core/permission/app_permission.dart';
import 'package:church_app/core/permission/mock_role_repository.dart';
import 'package:church_app/features/church/data/mock_church_repository.dart';
import 'package:church_app/features/church/data/mock_membership_repository.dart';
import 'package:church_app/features/home/data/mock_home_repository.dart';
import 'package:church_app/features/live/data/mock_live_access_service.dart';
import 'package:church_app/features/notices/data/mock_notice_repository.dart';
import 'package:church_app/features/popup_notices/data/api_popup_notice_repository.dart';
import 'package:church_app/features/popup_notices/data/popup_notice_repository.dart';
import 'package:church_app/features/popup_notices/data/popup_suppression_store.dart';
import 'package:church_app/features/popup_notices/domain/popup_notice_models.dart';
import 'package:church_app/features/popup_notices/presentation/popup_notice_host.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test(
    'permission parsing includes popup_notice.manage',
    () => expect(AppPermission.parseCodes(['popup_notice.manage']), {
      AppPermission.popupNoticeManage,
    }),
  );

  test('API parses UTC popup, optional relative image, null current, and overlap code', () async {
    final transport = _Transport([
      _json(_popupJson),
      const HttpTransportResponse(statusCode: 200, body: 'null'),
      _json({'detail': 'conflict', 'code': 'popup_notice_period_overlap'}, 409),
    ]);
    final repo = ApiPopupNoticeRepository(
      ApiClient(
        baseUri: Uri.parse('http://api.test'),
        transport: transport,
        tokenStore: MemoryTokenStore(),
      ),
    );
    final popup = await repo.get('church-a', '1');
    expect(popup.startsAt.isUtc, isTrue);
    expect(popup.image?.url, '/api/v1/churches/church-a/popup-notices/1/image');
    expect(await repo.current('church-a'), isNull);
    await expectLater(
      repo.setActive('church-a', '1', true),
      throwsA(
        isA<PopupNoticeDataException>().having(
          (e) => e.code,
          'code',
          'popup_notice_period_overlap',
        ),
      ),
    );
  });

  test('suppression is local-date, church, and popup isolated and persists across runtime reset', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final store = PopupSuppressionStore(preferences: Future.value(prefs));
    final local = DateTime(2026, 9, 3, 23, 30);
    await store.suppressToday('a', 'p1', local);
    expect(await store.isSuppressedToday('a', 'p1', local), isTrue);
    expect(
      await store.isSuppressedToday(
        'a',
        'p1',
        local.add(const Duration(days: 1)),
      ),
      isFalse,
    );
    expect(await store.isSuppressedToday('b', 'p1', local), isFalse);
    expect(await store.isSuppressedToday('a', 'p2', local), isFalse);
    expect(prefs.getString('popup_notice.dismissed.v1/a/p1'), '2026-09-03');
  });

  test('AppState fetches once per activation, ignores stale church response, claims once, and resets runtime on logout', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final repo = _PopupRepo();
    final app = _state(
      repo,
      PopupSuppressionStore(preferences: Future.value(prefs)),
    );
    final user = app.currentUser!;
    final a = user.approvedMemberships.first;
    final b = user.approvedMemberships.last;
    final aRequest = repo.expect('sky-gate');
    final activateA = app.activateChurch(a);
    await aRequest.started;
    final bRequest = repo.expect('bethel');
    final activateB = app.activateChurch(b);
    await bRequest.started;
    aRequest.complete(_popup('sky-gate', 'a'));
    bRequest.complete(_popup('bethel', 'b'));
    await Future.wait([activateA, activateB]);
    await Future<void>.delayed(Duration.zero);
    expect(repo.calls, ['sky-gate', 'bethel']);
    expect(app.pendingPopupNotice?.churchId, 'bethel');
    final popup = app.pendingPopupNotice!;
    expect(app.claimPendingPopup(popup), isTrue);
    expect(app.claimPendingPopup(popup), isFalse);
    app.dismissPopupForSession(popup);
    expect(app.pendingPopupNotice, isNull);
    await app.signOut();
    expect(
      app.claimPendingPopup(popup),
      isTrue,
    ); // claimed/session state reset; preference remains.
    expect(
      await prefs.getString('popup_notice.dismissed.v1/sky-gate/a'),
      isNull,
    );
  });

  testWidgets(
    'image popup dialog renders with bounded content on a small viewport',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final app = _state(
        _PopupRepo(),
        PopupSuppressionStore(preferences: Future.value(prefs)),
      );
      app.pendingPopupNotice = _popup(
        'sky-gate',
        'image',
        title: '긴 제목이 작은 화면에서도 자연스럽게 표시되어야 하는 팝업공지입니다',
        content: List<String>.filled(80, '긴 본문도 스크롤할 수 있어야 합니다.').join('\n'),
        image: const PopupNoticeImage(
          contentType: 'image/png',
          size: 68,
          url: '/image',
        ),
      );
      await tester.pumpWidget(
        AppScope(
          state: app,
          child: const MaterialApp(home: PopupNoticeHost(child: Scaffold())),
        ),
      );
      await tester.pump();
      await tester.pumpAndSettle();
      expect(find.textContaining('긴 제목이 작은 화면'), findsOneWidget);
      expect(find.textContaining('긴 본문도 스크롤'), findsOneWidget);
      expect(find.text('오늘 하루 보지 않기'), findsOneWidget);
      expect(find.text('닫기'), findsOneWidget);
      expect(find.byType(Image), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('no-image popup dialog renders without an image placeholder', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final app = _state(
      _PopupRepo(),
      PopupSuppressionStore(preferences: Future.value(prefs)),
    );
    app.pendingPopupNotice = _popup('sky-gate', 'plain');
    await tester.pumpWidget(
      AppScope(
        state: app,
        child: const MaterialApp(home: PopupNoticeHost(child: Scaffold())),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.text('title'), findsOneWidget);
    expect(find.text('content'), findsOneWidget);
    expect(find.byType(Image), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('닫기는 선택 상태에 따라 session 또는 today suppression을 유지한다', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final app = _state(
      _PopupRepo(),
      PopupSuppressionStore(preferences: Future.value(prefs)),
    );
    final popup = _popup('sky-gate', 'close');
    app.pendingPopupNotice = popup;
    await tester.pumpWidget(
      AppScope(
        state: app,
        child: const MaterialApp(home: PopupNoticeHost(child: Scaffold())),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('닫기'));
    await tester.pumpAndSettle();
    expect(app.pendingPopupNotice, isNull);
    expect(prefs.getString('popup_notice.dismissed.v1/sky-gate/close'), isNull);

    final todayPopup = _popup('sky-gate', 'today');
    app.pendingPopupNotice = todayPopup;
    app.notifyListeners();
    await tester.pump();
    await tester.pumpAndSettle();
    await tester.tap(find.text('오늘 하루 보지 않기'));
    await tester.pump();
    await tester.tap(find.text('닫기'));
    await tester.pumpAndSettle();
    expect(
      prefs.getString('popup_notice.dismissed.v1/sky-gate/today'),
      isNotNull,
    );
    expect(tester.takeException(), isNull);
  });
}

AppState _state(_PopupRepo repo, PopupSuppressionStore store) {
  final data = MockAppDataStore();
  final user = data.userById('user-a')!;
  return AppState(
    authRepository: MockAuthRepository(data),
    churchRepository: MockChurchRepository(data),
    membershipRepository: MockMembershipRepository(data),
    roleRepository: MockRoleRepository(data),
    homeRepository: MockHomeRepository(),
    liveAccessService: MockLiveAccessService(),
    noticeRepository: MockNoticeRepository(),
    popupNoticeRepository: repo,
    popupSuppressionStore: store,
  )..currentUser = user;
}

PopupNotice _popup(
  String church,
  String id, {
  PopupNoticeImage? image,
  String title = 'title',
  String content = 'content',
}) {
  final now = DateTime.utc(2026, 9, 3);
  return PopupNotice(
    id: id,
    churchId: church,
    authorMembershipId: '1',
    title: title,
    content: content,
    startsAt: now,
    endsAt: now.add(const Duration(days: 1)),
    isActive: true,
    createdAt: now,
    updatedAt: now,
    image: image,
  );
}

const _popupJson = {
  'id': 1,
  'church_id': 'church-a',
  'author_membership_id': 1,
  'title': 'title',
  'content': 'content',
  'starts_at': '2026-09-03T00:00:00Z',
  'ends_at': '2026-09-04T00:00:00Z',
  'is_active': true,
  'created_at': '2026-09-01T00:00:00Z',
  'updated_at': '2026-09-01T00:00:00Z',
  'image': {
    'content_type': 'image/png',
    'size': 12,
    'url': '/api/v1/churches/church-a/popup-notices/1/image',
  },
};
HttpTransportResponse _json(Object value, [int status = 200]) =>
    HttpTransportResponse(statusCode: status, body: jsonEncode(value));

class _Transport implements HttpTransport {
  _Transport(this.responses);
  final List<HttpTransportResponse> responses;
  @override
  Future<HttpTransportResponse> send({
    required String method,
    required Uri uri,
    required Map<String, String> headers,
    List<int>? bodyBytes,
  }) async => responses.removeAt(0);
  @override
  void close() {}
}

class _Request {
  final started = Completer<void>();
  final result = Completer<PopupNotice?>();
  void complete(PopupNotice? p) => result.complete(p);
}

class _PopupRepo implements PopupNoticeRepository {
  final calls = <String>[];
  final _requests = <String, _Request>{};
  _Request expect(String c) => _requests.putIfAbsent(c, _Request.new);
  @override
  Future<PopupNotice?> current(String c) {
    calls.add(c);
    final r = expect(c);
    r.started.complete();
    return r.result.future;
  }

  @override
  Future<List<int>> imageBytes(String path) async => const [
    137,
    80,
    78,
    71,
    13,
    10,
    26,
    10,
    0,
    0,
    0,
    13,
    73,
    72,
    68,
    82,
    0,
    0,
    0,
    1,
    0,
    0,
    0,
    1,
    8,
    6,
    0,
    0,
    0,
    31,
    21,
    196,
    137,
    0,
    0,
    0,
    13,
    73,
    68,
    65,
    84,
    8,
    215,
    99,
    248,
    207,
    192,
    240,
    31,
    0,
    5,
    0,
    1,
    255,
    137,
    153,
    61,
    29,
    0,
    0,
    0,
    0,
    73,
    69,
    78,
    68,
    174,
    66,
    96,
    130,
  ];
  @override
  noSuchMethod(Invocation i) => super.noSuchMethod(i);
}
