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
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('공지 수정 응답으로 상세를 갱신하고 detail GET을 다시 호출하지 않는다', (tester) async {
    final repository = _RecordingNoticeRepository();
    final store = MockAppDataStore();
    final user = store.userById('user-c')!;
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
          ..status = AppSessionStatus.authenticated
          ..toggleRuntimePermission(AppPermission.noticeUpdate);
    await tester.pumpWidget(
      AppScope(
        state: state,
        child: const MaterialApp(home: NoticeDetailScreen(noticeId: '1')),
      ),
    );
    await tester.pumpAndSettle();
    expect(repository.detailFetches, 1);
    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), '수정 제목');
    await tester.enterText(fields.at(1), '수정 본문');
    await tester.tap(find.byType(Switch));
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('수정 제목'), findsOneWidget);
    expect(find.text('수정 본문'), findsOneWidget);
    expect(find.text('고정공지'), findsOneWidget);
    expect(repository.detailFetches, 1);
  });
}

class _RecordingNoticeRepository implements NoticeRepository {
  int detailFetches = 0;
  Notice _notice = _noticeOf();
  @override
  Future<List<Notice>> listNotices(String churchId) async => [_notice];
  @override
  Future<Notice> getNotice(String churchId, String noticeId) async {
    detailFetches++;
    return _notice;
  }

  @override
  Future<Notice> createNotice(String churchId, NoticeDraft draft) async =>
      _notice;
  @override
  Future<Notice> updateNotice(
    String churchId,
    String noticeId,
    NoticeDraft draft,
  ) async {
    _notice = Notice(
      id: '1',
      churchId: churchId,
      title: draft.title,
      content: draft.content,
      isPinned: draft.isPinned,
      publishedAt: _notice.publishedAt,
      createdAt: _notice.createdAt,
      updatedAt: DateTime.now(),
    );
    return _notice;
  }

  @override
  Future<void> deleteNotice(String churchId, String noticeId) async {}
}

Notice _noticeOf() {
  final now = DateTime(2026, 9, 2);
  return Notice(
    id: '1',
    churchId: 'sky-gate',
    title: '기존 제목',
    content: '기존 본문',
    isPinned: false,
    publishedAt: now,
    createdAt: now,
    updatedAt: now,
  );
}
