import 'dart:async';

import 'package:church_app/app/app_scope.dart';
import 'package:church_app/app/app_state.dart';
import 'package:church_app/core/auth/mock_auth_repository.dart';
import 'package:church_app/core/mock/mock_app_data_store.dart';
import 'package:church_app/core/permission/app_permission.dart';
import 'package:church_app/core/permission/mock_role_repository.dart';
import 'package:church_app/features/church/data/mock_church_repository.dart';
import 'package:church_app/features/church/data/mock_membership_repository.dart';
import 'package:church_app/features/home/data/mock_home_repository.dart';
import 'package:church_app/features/live/data/mock_live_access_service.dart';
import 'package:church_app/features/notices/data/notice_repository.dart';
import 'package:church_app/features/notices/domain/notice_models.dart';
import 'package:church_app/features/notices/presentation/notice_detail_screen.dart';
import 'package:church_app/features/notices/presentation/notice_editor_screen.dart';
import 'package:church_app/features/notices/presentation/notices_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('공지 목록은 작성 권한과 고정 정보를 분명히 표시한다', (tester) async {
    final repository = _NoticeRecordingRepository();
    final state = _state(repository, {
      AppPermission.noticeView,
      AppPermission.noticeCreate,
    });

    await tester.pumpWidget(_app(state, const NoticesScreen()));
    await tester.pumpAndSettle();

    expect(find.byTooltip('공지 작성'), findsOneWidget);
    expect(find.text('고정'), findsOneWidget);
    expect(find.text('고정 공지'), findsOneWidget);
    expect(find.text('목록에 노출되면 안 되는 본문'), findsNothing);
  });

  testWidgets('작성 권한이 없으면 목록에 작성 action이 없다', (tester) async {
    final state = _state(_NoticeRecordingRepository(), {
      AppPermission.noticeView,
    });

    await tester.pumpWidget(_app(state, const NoticesScreen()));
    await tester.pumpAndSettle();

    expect(find.byTooltip('공지 작성'), findsNothing);
  });

  testWidgets('상세는 권한별 수정과 삭제 action을 구분해 표시한다', (tester) async {
    final noActionState = _state(_NoticeRecordingRepository(), {
      AppPermission.noticeView,
    });
    await tester.pumpWidget(
      _app(noActionState, const NoticeDetailScreen(noticeId: 'notice-1')),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip('공지 수정'), findsNothing);
    expect(find.byTooltip('공지 삭제'), findsNothing);
    expect(find.text('고정'), findsOneWidget);
    expect(find.text('목록에 노출되면 안 되는 본문'), findsOneWidget);
    expect(find.text('2026년 9월 2일'), findsOneWidget);

    final actionState = _state(_NoticeRecordingRepository(), {
      AppPermission.noticeView,
      AppPermission.noticeUpdate,
      AppPermission.noticeDelete,
    });
    await tester.pumpWidget(
      _app(actionState, const NoticeDetailScreen(noticeId: 'notice-1')),
    );
    await tester.pumpAndSettle();
    expect(find.byTooltip('공지 수정'), findsOneWidget);
    expect(find.byTooltip('공지 삭제'), findsOneWidget);
  });

  testWidgets('삭제 확인 취소는 요청하지 않고, 삭제 확인은 기존 delete flow를 호출한다', (tester) async {
    final repository = _NoticeRecordingRepository();
    final state = _state(repository, {
      AppPermission.noticeView,
      AppPermission.noticeDelete,
    });

    await tester.pumpWidget(
      _app(state, const NoticeDetailScreen(noticeId: 'notice-1')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('공지 삭제'));
    await tester.pumpAndSettle();
    expect(find.text('삭제한 공지사항은 복구할 수 없습니다.'), findsOneWidget);
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
    expect(repository.deleteCalls, 0);

    await tester.tap(find.byTooltip('공지 삭제'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('삭제'));
    await tester.pumpAndSettle();
    expect(repository.deleteCalls, 1);
  });

  testWidgets('저장 실패 후에도 공지 editor의 입력 내용은 유지된다', (tester) async {
    final repository = _NoticeRecordingRepository()..failCreate = true;
    final state = _state(repository, {AppPermission.noticeCreate});

    await tester.pumpWidget(_app(state, const NoticeEditorScreen()));
    await tester.enterText(find.byType(TextField).at(0), '작성 중 제목');
    await tester.enterText(find.byType(TextField).at(1), '작성 중 본문');
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();

    expect(find.text('저장하지 못했습니다. 입력 내용과 권한을 확인해주세요.'), findsOneWidget);
    expect(find.text('작성 중 제목'), findsOneWidget);
    expect(find.text('작성 중 본문'), findsOneWidget);
  });

  testWidgets('저장 중에는 같은 공지 mutation을 다시 전송하지 않는다', (tester) async {
    final repository = _NoticeRecordingRepository()..holdCreate = true;
    final state = _state(repository, {AppPermission.noticeCreate});

    await tester.pumpWidget(_app(state, const NoticeEditorScreen()));
    await tester.enterText(find.byType(TextField).at(0), '제목');
    await tester.enterText(find.byType(TextField).at(1), '본문');
    await tester.tap(find.text('저장'));
    await tester.pump();
    await tester.tap(find.byType(FilledButton));
    await tester.pump();

    expect(repository.createCalls, 1);
    repository.completeCreate();
    await tester.pumpAndSettle();
  });
}

Widget _app(AppState state, Widget home) => AppScope(
  state: state,
  child: MaterialApp(home: home),
);

AppState _state(NoticeRepository repository, Set<AppPermission> permissions) {
  final store = MockAppDataStore();
  final user = store.userById('user-a')!;
  final state =
      AppState(
          authRepository: MockAuthRepository(store),
          churchRepository: MockChurchRepository(store),
          membershipRepository: MockMembershipRepository(store),
          roleRepository: MockRoleRepository(store),
          homeRepository: MockHomeRepository(),
          liveAccessService: MockLiveAccessService(),
          noticeRepository: repository,
        )
        ..currentUser = user
        ..activeMembership = user.approvedMemberships.first
        ..status = AppSessionStatus.authenticated;
  for (final permission in permissions) {
    state.toggleRuntimePermission(permission);
  }
  return state;
}

class _NoticeRecordingRepository implements NoticeRepository {
  int deleteCalls = 0;
  int createCalls = 0;
  bool failCreate = false;
  bool holdCreate = false;
  Completer<Notice>? _pendingCreate;
  final Notice notice = Notice(
    id: 'notice-1',
    churchId: 'sky-gate',
    title: '고정 공지',
    content: '목록에 노출되면 안 되는 본문',
    isPinned: true,
    publishedAt: DateTime(2026, 9, 2),
    createdAt: DateTime(2026, 9, 2),
    updatedAt: DateTime(2026, 9, 2),
  );

  @override
  Future<List<Notice>> listNotices(String churchId) async => [notice];
  @override
  Future<Notice> getNotice(String churchId, String noticeId) async => notice;
  @override
  Future<Notice> createNotice(String churchId, NoticeDraft draft) {
    createCalls++;
    if (failCreate) throw const NoticeDataException('save failed');
    if (holdCreate) return (_pendingCreate ??= Completer<Notice>()).future;
    return Future.value(notice);
  }

  @override
  Future<Notice> updateNotice(
    String churchId,
    String noticeId,
    NoticeDraft draft,
  ) async => notice;
  @override
  Future<void> deleteNotice(String churchId, String noticeId) async {
    deleteCalls++;
  }

  void completeCreate() => _pendingCreate?.complete(notice);
}
