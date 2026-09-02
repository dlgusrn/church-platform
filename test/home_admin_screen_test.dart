import 'package:church_app/app/app_scope.dart';
import 'package:church_app/app/app_state.dart';
import 'package:church_app/core/auth/mock_auth_repository.dart';
import 'package:church_app/core/mock/mock_app_data_store.dart';
import 'package:church_app/core/permission/app_permission.dart';
import 'package:church_app/core/permission/mock_role_repository.dart';
import 'package:church_app/features/church/data/mock_church_repository.dart';
import 'package:church_app/features/church/data/mock_membership_repository.dart';
import 'package:church_app/features/home/data/home_repository.dart';
import 'package:church_app/features/home/domain/home_models.dart';
import 'package:church_app/features/home/presentation/live_broadcast_admin_screen.dart';
import 'package:church_app/features/home/presentation/worship_schedule_admin_screen.dart';
import 'package:church_app/features/live/data/mock_live_access_service.dart';
import 'package:church_app/features/notices/data/mock_notice_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('예배 일정 저장 refresh는 Future를 반환하지 않고 한 번만 조회한다', (tester) async {
    final repository = RecordingHomeRepository();
    final state = createAdminState(repository);

    await tester.pumpWidget(
      AppScope(
        state: state,
        child: const MaterialApp(home: WorshipScheduleAdminScreen()),
      ),
    );
    await tester.pump();
    expect(repository.scheduleFetches, 1);

    state.toggleRuntimePermission(AppPermission.vodView);
    await tester.pump();
    expect(repository.scheduleFetches, 1);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), '테스트 예배');
    await tester.enterText(fields.at(1), '주일 오전');
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(repository.scheduleCreates, 1);
    expect(repository.scheduleFetches, 2);
  });

  testWidgets('LIVE 저장 refresh는 Future를 반환하지 않고 한 번만 조회한다', (tester) async {
    final repository = RecordingHomeRepository();
    final state = createAdminState(repository);

    await tester.pumpWidget(
      AppScope(
        state: state,
        child: const MaterialApp(home: LiveBroadcastAdminScreen()),
      ),
    );
    await tester.pump();
    expect(repository.liveFetches, 1);

    state.toggleRuntimePermission(AppPermission.vodView);
    await tester.pump();
    expect(repository.liveFetches, 1);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), '특별 방송');
    await tester.enterText(fields.at(1), 'https://youtu.be/test-live');
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(repository.liveCreates, 1);
    expect(repository.liveFetches, 2);
  });
}

AppState createAdminState(HomeRepository homeRepository) {
  final store = MockAppDataStore();
  final state = AppState(
    authRepository: MockAuthRepository(store),
    churchRepository: MockChurchRepository(store),
    membershipRepository: MockMembershipRepository(store),
    roleRepository: MockRoleRepository(store),
    homeRepository: homeRepository,
    liveAccessService: MockLiveAccessService(),
    noticeRepository: MockNoticeRepository(),
  );
  final user = store.userById('user-c')!;
  state
    ..currentUser = user
    ..activeMembership = user.approvedMemberships.first
    ..status = AppSessionStatus.authenticated
    ..toggleRuntimePermission(AppPermission.scheduleManage)
    ..toggleRuntimePermission(AppPermission.liveManage);
  return state;
}

class RecordingHomeRepository implements HomeRepository {
  int scheduleFetches = 0;
  int scheduleCreates = 0;
  int liveFetches = 0;
  int liveCreates = 0;
  final List<WorshipSchedule> schedules = [];
  final List<LiveBroadcast> broadcasts = [];

  @override
  Future<HomeContent> getHomeContent(
    String churchId, {
    bool includeSchedules = true,
  }) async => HomeContent(
    live: null,
    schedules: includeSchedules ? List.unmodifiable(schedules) : const [],
    recentVideos: const [],
  );

  @override
  Future<List<WorshipSchedule>> getWorshipSchedules(
    String churchId, {
    bool includeInactive = false,
  }) async {
    scheduleFetches++;
    return List.unmodifiable(schedules);
  }

  @override
  Future<WorshipSchedule> createWorshipSchedule(
    String churchId,
    WorshipScheduleDraft draft,
  ) async {
    scheduleCreates++;
    final schedule = WorshipSchedule(
      id: 'schedule-$scheduleCreates',
      churchId: churchId,
      title: draft.title,
      dayLabel: draft.dayLabel,
      time: draft.time,
      displayOrder: draft.displayOrder,
      isActive: draft.isActive,
    );
    schedules.add(schedule);
    return schedule;
  }

  @override
  Future<WorshipSchedule> updateWorshipSchedule(
    String churchId,
    String scheduleId,
    WorshipScheduleDraft draft,
  ) => throw UnimplementedError();

  @override
  Future<List<LiveBroadcast>> getLiveBroadcasts(String churchId) async {
    liveFetches++;
    return List.unmodifiable(broadcasts);
  }

  @override
  Future<LiveBroadcast> createLiveBroadcast(
    String churchId,
    LiveBroadcastDraft draft,
  ) async {
    liveCreates++;
    final broadcast = LiveBroadcast(
      id: 'live-$liveCreates',
      churchId: churchId,
      broadcastDate: draft.broadcastDate,
      worshipType: draft.worshipType,
      customWorshipName: draft.customWorshipName,
      titleOverride: draft.titleOverride,
      displayTitle: draft.titleOverride ?? '특별 방송',
      youtubeUrl: draft.youtubeUrl,
      status: draft.status,
    );
    broadcasts.add(broadcast);
    return broadcast;
  }

  @override
  Future<LiveBroadcast> updateLiveBroadcast(
    String churchId,
    String broadcastId,
    LiveBroadcastDraft draft,
  ) => throw UnimplementedError();
}
