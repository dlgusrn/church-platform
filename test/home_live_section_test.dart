import 'package:church_app/app/app_scope.dart';
import 'package:church_app/app/app_state.dart';
import 'package:church_app/core/auth/mock_auth_repository.dart';
import 'package:church_app/core/mock/mock_app_data_store.dart';
import 'package:church_app/core/permission/app_permission.dart';
import 'package:church_app/core/permission/mock_role_repository.dart';
import 'package:church_app/features/church/data/mock_church_repository.dart';
import 'package:church_app/features/church/data/mock_membership_repository.dart';
import 'package:church_app/features/home/data/mock_home_repository.dart';
import 'package:church_app/features/home/domain/home_models.dart';
import 'package:church_app/features/home/presentation/home_screen.dart';
import 'package:church_app/features/live/data/mock_live_access_service.dart';
import 'package:church_app/features/notices/data/mock_notice_repository.dart';
import 'package:church_app/features/notices/domain/notice_models.dart';
import 'package:church_app/shared/models/user.dart';
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
    expect(find.byIcon(Icons.live_tv_outlined), findsNothing);
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

  testWidgets('schedule.view 없이도 전달된 Home 예배시간 안내는 표시한다', (tester) async {
    final store = MockAppDataStore();
    final user = store.userById('user-b')!;
    final state = _state(store, user, user.approvedMemberships.single)
      ..homeContent = HomeContent(
        live: null,
        schedules: const [
          WorshipSchedule(
            id: 'worship',
            churchId: 'sky-gate',
            title: '주일예배',
            dayLabel: '주일',
            time: '11:00:00',
            displayOrder: 0,
            isActive: true,
          ),
        ],
        recentVideos: const [],
      );

    await tester.pumpWidget(
      AppScope(
        state: state,
        child: const MaterialApp(home: HomeScreen()),
      ),
    );

    expect(find.text('예배시간 안내'), findsOneWidget);
    expect(find.text('주일 · 주일예배'), findsOneWidget);
    expect(find.text('11:00'), findsOneWidget);
    expect(find.text('주일예배'), findsNothing);
    expect(find.text('최근 공지사항'), findsNothing);
    expect(find.text('최근 영상'), findsOneWidget);
  });

  testWidgets('notice.view가 있으면 최근 공지사항 section을 표시한다', (tester) async {
    final store = MockAppDataStore();
    final user = store.userById('user-c')!;
    final state = _state(store, user, user.approvedMemberships.first)
      ..homeContent = const HomeContent(
        live: null,
        schedules: [],
        recentVideos: [],
      )
      ..homeNotices = [_notice()];

    await tester.pumpWidget(
      AppScope(
        state: state,
        child: const MaterialApp(home: HomeScreen()),
      ),
    );

    expect(find.text('최근 공지사항'), findsOneWidget);
    expect(find.text('홈 공지'), findsOneWidget);
  });

  testWidgets('schedule.view 없이도 approved Home load는 예배시간을 요청하고 공지를 요청하지 않는다', (
    tester,
  ) async {
    final store = MockAppDataStore();
    final user = store.userById('user-b')!;
    final homeRepository = RecordingHomeRepository();
    final noticeRepository = RecordingNoticeRepository();
    final state = AppState(
      authRepository: MockAuthRepository(store),
      churchRepository: MockChurchRepository(store),
      membershipRepository: MockMembershipRepository(store),
      roleRepository: MockRoleRepository(store),
      homeRepository: homeRepository,
      liveAccessService: MockLiveAccessService(),
      noticeRepository: noticeRepository,
    )..currentUser = user;

    await state.activateChurch(user.approvedMemberships.single);

    expect(state.has(AppPermission.scheduleView), isFalse);
    expect(homeRepository.homeLoads, 1);
    expect(homeRepository.includeSchedules, isTrue);
    expect(noticeRepository.listFetches, 0);
    expect(await state.loadManagedWorshipSchedules(), isEmpty);

    await tester.pumpWidget(
      AppScope(
        state: state,
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    expect(find.text('예배시간 안내'), findsOneWidget);
    expect(find.text('주일 · 모든 성도를 위한 예배'), findsOneWidget);
  });

  testWidgets('홈은 일반 viewport에서 본문을 스크롤하지 않는다', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpHome(tester, null);

    final scrollable = tester.state<ScrollableState>(find.byType(Scrollable));
    expect(scrollable.position.maxScrollExtent, 0);
    await tester.drag(find.byType(Scrollable), const Offset(0, -120));
    await tester.pump();
    expect(scrollable.position.pixels, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('홈은 작은 viewport에서 본문을 스크롤한다', (tester) async {
    tester.view.physicalSize = const Size(320, 360);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpHome(tester, null);

    final scrollable = tester.state<ScrollableState>(find.byType(Scrollable));
    expect(scrollable.position.maxScrollExtent, greaterThan(0));
    await tester.drag(find.byType(Scrollable), const Offset(0, -120));
    await tester.pump();
    expect(scrollable.position.pixels, greaterThan(0));
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpHome(WidgetTester tester, LiveBroadcast? live) async {
  final store = MockAppDataStore();
  final user = store.userById('user-c')!;
  final state = _state(store, user, user.approvedMemberships.first)
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

AppState _state(
  MockAppDataStore store,
  AppUser user,
  ChurchMembership membership,
) =>
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
      ..activeMembership = membership
      ..status = AppSessionStatus.authenticated;

Notice _notice() {
  final at = DateTime(2026, 9, 3);
  return Notice(
    id: 'notice',
    churchId: 'sky-gate',
    title: '홈 공지',
    content: '본문',
    isPinned: false,
    publishedAt: at,
    createdAt: at,
    updatedAt: at,
  );
}

class RecordingHomeRepository extends MockHomeRepository {
  int homeLoads = 0;
  bool? includeSchedules;

  @override
  Future<HomeContent> getHomeContent(
    String churchId, {
    bool includeSchedules = true,
  }) async {
    homeLoads++;
    this.includeSchedules = includeSchedules;
    return HomeContent(
      live: null,
      schedules: includeSchedules
          ? [
              WorshipSchedule(
                id: 'guide',
                churchId: churchId,
                title: '모든 성도를 위한 예배',
                dayLabel: '주일',
                time: '11:00:00',
                displayOrder: 0,
                isActive: true,
              ),
            ]
          : const [],
      recentVideos: const [],
    );
  }
}

class RecordingNoticeRepository extends MockNoticeRepository {
  int listFetches = 0;

  @override
  Future<List<Notice>> listNotices(String churchId) async {
    listFetches++;
    return super.listNotices(churchId);
  }
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
