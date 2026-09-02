import 'package:church_app/app/app_scope.dart';
import 'package:church_app/app/app_state.dart';
import 'package:church_app/core/auth/mock_auth_repository.dart';
import 'package:church_app/core/mock/mock_app_data_store.dart';
import 'package:church_app/core/permission/mock_role_repository.dart';
import 'package:church_app/features/church/data/mock_church_repository.dart';
import 'package:church_app/features/church/data/mock_membership_repository.dart';
import 'package:church_app/features/home/data/mock_home_repository.dart';
import 'package:church_app/features/home/domain/home_models.dart';
import 'package:church_app/features/home/presentation/home_screen.dart';
import 'package:church_app/features/live/data/mock_live_access_service.dart';
import 'package:church_app/features/notices/data/mock_notice_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('live 방송이 있으면 LIVE 카드를 표시한다', (tester) async {
    await _pumpHome(tester, _broadcast(LiveBroadcastStatus.live));

    expect(find.byType(LiveCard), findsOneWidget);
    expect(find.byType(LiveEmptyCard), findsNothing);
  });

  testWidgets('방송이 없으면 LIVE 영역에 empty state를 표시한다', (tester) async {
    await _pumpHome(tester, null);

    expect(find.byType(LiveCard), findsNothing);
    expect(find.byType(LiveEmptyCard), findsOneWidget);
    expect(find.text('지금은\n예배시간이 아닙니다 :)'), findsOneWidget);
  });

  testWidgets('scheduled 방송만 있어도 LIVE empty state를 표시한다', (tester) async {
    await _pumpHome(tester, _broadcast(LiveBroadcastStatus.scheduled));

    expect(find.byType(LiveCard), findsNothing);
    expect(find.byType(LiveEmptyCard), findsOneWidget);
  });

  testWidgets('ended 방송만 있어도 LIVE empty state를 표시한다', (tester) async {
    await _pumpHome(tester, _broadcast(LiveBroadcastStatus.ended));

    expect(find.byType(LiveCard), findsNothing);
    expect(find.byType(LiveEmptyCard), findsOneWidget);
  });
}

Future<void> _pumpHome(WidgetTester tester, LiveBroadcast? live) async {
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
          noticeRepository: MockNoticeRepository(),
        )
        ..currentUser = user
        ..activeMembership = user.approvedMemberships.first
        ..status = AppSessionStatus.authenticated
        ..homeContent = HomeContent(
          live: live,
          schedules: const [],
          recentVideos: const [],
        );

  await tester.pumpWidget(
    AppScope(
      state: state,
      child: const MaterialApp(home: HomeScreen()),
    ),
  );
}

LiveBroadcast _broadcast(LiveBroadcastStatus status) => LiveBroadcast(
  id: 'live-1',
  churchId: 'church-1',
  worshipType: LiveWorshipType.day,
  broadcastDate: DateTime(2026, 9, 2),
  displayTitle: '주일예배 생방송',
  youtubeUrl: 'https://youtu.be/live',
  status: status,
);
