import 'package:church_app/app/app_state.dart';
import 'package:church_app/app/app_scope.dart';
import 'package:church_app/app/app.dart';
import 'package:church_app/core/auth/auth_repository.dart';
import 'package:church_app/core/auth/mock_auth_repository.dart';
import 'package:church_app/core/mock/mock_app_data_store.dart';
import 'package:church_app/core/navigation/app_destination.dart';
import 'package:church_app/core/permission/app_permission.dart';
import 'package:church_app/core/permission/effective_permission.dart';
import 'package:church_app/core/permission/mock_role_repository.dart';
import 'package:church_app/features/church/data/membership_repository.dart';
import 'package:church_app/features/church/data/mock_church_repository.dart';
import 'package:church_app/features/church/data/mock_membership_repository.dart';
import 'package:church_app/features/home/data/mock_home_repository.dart';
import 'package:church_app/features/home/domain/home_models.dart';
import 'package:church_app/features/live/data/mock_live_access_service.dart';
import 'package:church_app/features/notices/data/mock_notice_repository.dart';
import 'package:church_app/features/more/presentation/more_screen.dart';
import 'package:church_app/shared/models/user.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class CountingHomeRepository extends MockHomeRepository {
  int homeLoadCount = 0;

  @override
  Future<HomeContent> getHomeContent(
    String churchId, {
    bool includeSchedules = true,
  }) {
    homeLoadCount++;
    return super.getHomeContent(churchId, includeSchedules: includeSchedules);
  }
}

class RestoringMockAuthRepository extends MockAuthRepository {
  RestoringMockAuthRepository(super.store, this.userId);

  final String userId;

  @override
  Future<AppUser?> restoreSession() async => store.userById(userId);
}

({AppState state, MockAppDataStore store, CountingHomeRepository home})
createFixture() {
  final store = MockAppDataStore();
  final home = CountingHomeRepository();
  return (
    store: store,
    home: home,
    state: AppState(
      authRepository: MockAuthRepository(store),
      churchRepository: MockChurchRepository(store),
      membershipRepository: MockMembershipRepository(store),
      roleRepository: MockRoleRepository(store),
      homeRepository: home,
      liveAccessService: MockLiveAccessService(),
      noticeRepository: MockNoticeRepository(),
    ),
  );
}

void main() {
  test('Case 1: 회원가입 후 교회 가입 신청은 pending과 빈 Permission으로 생성된다', () async {
    final fixture = createFixture();
    expect(
      await fixture.state.register(
        name: '가입 테스트',
        loginId: 'join@test.app',
        password: '123456',
      ),
      isTrue,
    );
    expect(fixture.state.status, AppSessionStatus.selectingJoinChurch);
    final membership = await fixture.state.requestJoin(
      fixture.state.churches.first,
      onboarding: true,
    );
    expect(membership?.status, MembershipStatus.pending);
    expect(membership?.role, isNull);
    expect(membership?.effectivePermissions, isEmpty);
    expect(fixture.state.status, AppSessionStatus.approvalPending);
    expect(fixture.home.homeLoadCount, 0);
  });

  test('pending 회원은 승인 여부를 확인해도 Home API를 호출하지 않는다', () async {
    final fixture = createFixture();
    await fixture.state.register(
      name: '승인 대기 테스트',
      loginId: 'pending-check@test.app',
      password: '123456',
    );
    await fixture.state.requestJoin(
      fixture.state.churches.first,
      onboarding: true,
    );

    expect(
      await fixture.state.checkPendingMembershipApproval(),
      PendingMembershipCheckResult.pending,
    );
    expect(fixture.state.status, AppSessionStatus.approvalPending);
    expect(fixture.state.activeMembership, isNull);
    expect(fixture.home.homeLoadCount, 0);
  });

  test('승인된 pending 회원은 권한을 반영하고 Home으로 진입한다', () async {
    final fixture = createFixture();
    await fixture.state.register(
      name: '승인 전환 테스트',
      loginId: 'approved-check@test.app',
      password: '123456',
    );
    final pending = await fixture.state.requestJoin(
      fixture.state.churches.first,
      onboarding: true,
    );
    await MockMembershipRepository(fixture.store).approve(
      churchId: pending!.church.id,
      membershipId: pending.id,
      role: MockAppDataStore.memberRole,
    );

    expect(
      await fixture.state.checkPendingMembershipApproval(),
      PendingMembershipCheckResult.approved,
    );
    expect(fixture.state.status, AppSessionStatus.authenticated);
    expect(fixture.state.activeMembership?.isApproved, isTrue);
    expect(fixture.state.has(AppPermission.liveAccess), isTrue);
    expect(fixture.state.has(AppPermission.vodView), isTrue);
    expect(fixture.home.homeLoadCount, 1);
    expect(
      NavigationPolicy.available(fixture.state.effectivePermissions)
          .map((item) => item.label),
      ['홈', '영상', '더보기'],
    );
  });

  testWidgets('승인 여부 확인은 pending 화면을 유지하다 승인 후 MainShell로 전환한다', (
    tester,
  ) async {
    final fixture = createFixture();
    await fixture.state.register(
      name: '승인 화면 테스트',
      loginId: 'approval-screen@test.app',
      password: '123456',
    );
    final pending = await fixture.state.requestJoin(
      fixture.state.churches.first,
      onboarding: true,
    );

    await tester.pumpWidget(ChurchApp(appState: fixture.state));
    expect(find.text('가입 신청이 완료되었습니다'), findsOneWidget);
    expect(find.text('승인 여부 확인'), findsOneWidget);

    await tester.tap(find.text('승인 여부 확인'));
    await tester.pumpAndSettle();
    expect(find.text('아직 승인 대기 중입니다. 관리자 승인 후 다시 확인해주세요.'), findsOneWidget);
    expect(fixture.state.status, AppSessionStatus.approvalPending);
    expect(fixture.home.homeLoadCount, 0);

    await MockMembershipRepository(fixture.store).approve(
      churchId: pending!.church.id,
      membershipId: pending.id,
      role: MockAppDataStore.memberRole,
    );
    await tester.tap(find.text('승인 여부 확인'));
    await tester.pumpAndSettle();

    expect(fixture.state.status, AppSessionStatus.authenticated);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('홈'), findsOneWidget);
    expect(find.text('영상'), findsOneWidget);
    expect(find.text('더보기'), findsOneWidget);
  });

  test('거절된 pending 회원은 가입 현황 화면으로 이동한다', () async {
    final fixture = createFixture();
    await fixture.state.register(
      name: '거절 전환 테스트',
      loginId: 'rejected-check@test.app',
      password: '123456',
    );
    final pending = await fixture.state.requestJoin(
      fixture.state.churches.first,
      onboarding: true,
    );
    await MockMembershipRepository(fixture.store)
        .reject(churchId: pending!.church.id, membershipId: pending.id);

    expect(
      await fixture.state.checkPendingMembershipApproval(),
      PendingMembershipCheckResult.rejected,
    );
    expect(fixture.state.status, AppSessionStatus.membershipStatus);
    expect(fixture.state.activeMembership, isNull);
    expect(fixture.home.homeLoadCount, 0);
  });

  test('approved 교회와 다른 교회의 pending 신청은 기존 Home 진입을 막지 않는다', () async {
    final fixture = createFixture();
    final user = fixture.store.userById('user-b')!;
    final pending = ChurchMembership(
      id: 'membership-b-pending',
      userId: user.id,
      church: fixture.store.churches.last,
      status: MembershipStatus.pending,
      requestedAt: DateTime(2026, 9, 23),
    );
    fixture.store.replaceUser(
      user.copyWith(memberships: [...user.memberships, pending]),
    );

    await fixture.state.signIn(
      loginId: 'member@church.app',
      password: 'test1234',
    );

    expect(fixture.state.status, AppSessionStatus.authenticated);
    expect(fixture.state.activeMembership?.church.id, 'sky-gate');
    expect(fixture.home.homeLoadCount, 1);
  });

  test('세션 복구 시 pending membership만 있으면 승인 대기 화면에 머문다', () async {
    final store = MockAppDataStore();
    const userId = 'restoring-pending-user';
    final pendingUser = AppUser(
      id: userId,
      name: '세션 복구 대기 회원',
      loginId: 'restore-pending@test.app',
      memberships: [
        ChurchMembership(
          id: 'restoring-pending-membership',
          userId: userId,
          church: store.churches.first,
          status: MembershipStatus.pending,
          requestedAt: DateTime(2026, 9, 23),
        ),
      ],
    );
    store.users.add(pendingUser);
    final home = CountingHomeRepository();
    final state = AppState(
      authRepository: RestoringMockAuthRepository(store, userId),
      churchRepository: MockChurchRepository(store),
      membershipRepository: MockMembershipRepository(store),
      roleRepository: MockRoleRepository(store),
      homeRepository: home,
      liveAccessService: MockLiveAccessService(),
      noticeRepository: MockNoticeRepository(),
    );

    await state.restoreSession();

    expect(state.status, AppSessionStatus.approvalPending);
    expect(state.activeMembership, isNull);
    expect(state.lastRequestedMembership?.id, 'restoring-pending-membership');
    expect(home.homeLoadCount, 0);
  });

  test('Case 2: pending 또는 approved 교회에는 중복 신청할 수 없다', () async {
    final fixture = createFixture();
    final auth = MockAuthRepository(fixture.store);
    final user = await auth.register(
      const RegisterRequest(
        name: '중복 테스트',
        loginId: 'duplicate@test.app',
        password: '123456',
      ),
    );
    final repository = MockMembershipRepository(fixture.store);
    await repository.requestJoin(userId: user.id, churchId: 'sky-gate');
    expect(
      () => repository.requestJoin(userId: user.id, churchId: 'sky-gate'),
      throwsA(isA<MembershipException>()),
    );
    final existing = fixture.store.userById('user-b')!;
    expect(
      () => repository.requestJoin(userId: existing.id, churchId: 'sky-gate'),
      throwsA(isA<MembershipException>()),
    );
  });

  test('Case 3: 성도 Role 승인 후 live.access와 vod.view가 적용된다', () async {
    final fixture = createFixture();
    final auth = MockAuthRepository(fixture.store);
    final repository = MockMembershipRepository(fixture.store);
    final user = await auth.register(
      const RegisterRequest(
        name: '승인 테스트',
        loginId: 'approve@test.app',
        password: '123456',
      ),
    );
    final pending = await repository.requestJoin(
      userId: user.id,
      churchId: 'sky-gate',
    );
    final approved = await repository.approve(
      churchId: pending.church.id,
      membershipId: pending.id,
      role: MockAppDataStore.memberRole,
    );
    expect(approved.status, MembershipStatus.approved);
    expect(approved.effectivePermissions, {
      AppPermission.liveAccess,
      AppPermission.vodView,
    });
  });

  test('Case 4: 한 교회 거절은 계정 로그인과 다른 교회 Membership에 영향이 없다', () async {
    final fixture = createFixture();
    final auth = MockAuthRepository(fixture.store);
    final repository = MockMembershipRepository(fixture.store);
    final user = await auth.register(
      const RegisterRequest(
        name: '거절 테스트',
        loginId: 'reject@test.app',
        password: '123456',
      ),
    );
    final first = await repository.requestJoin(
      userId: user.id,
      churchId: 'sky-gate',
    );
    await repository.requestJoin(userId: user.id, churchId: 'bethel');
    await repository.reject(churchId: first.church.id, membershipId: first.id);
    final signedIn = await auth.signIn(
      loginId: 'reject@test.app',
      password: '123456',
    );
    expect(signedIn.memberships.first.status, MembershipStatus.rejected);
    expect(signedIn.memberships.last.status, MembershipStatus.pending);
  });

  test('Case 5: 복수 교회 전환 시 Role, Permission, 메뉴가 교회별로 격리된다', () async {
    final fixture = createFixture();
    await fixture.state.signIn(
      loginId: 'staff@church.app',
      password: 'test1234',
    );
    await fixture.state.activateChurch(
      fixture.state.currentUser!.approvedMemberships.first,
    );
    expect(
      NavigationPolicy.available(fixture.state.effectivePermissions)
          .map((item) => item.label),
      ['홈', '영상', '음성', '업무', '더보기'],
    );
    await fixture.state.activateChurch(
      fixture.state.currentUser!.approvedMemberships.last,
    );
    expect(fixture.state.activeMembership!.roleName, '성도');
    expect(
      NavigationPolicy.available(fixture.state.effectivePermissions)
          .map((item) => item.label),
      ['홈', '영상', '더보기'],
    );
  });

  test('activeChurch 변경 중 이전 교회의 홈 LIVE를 즉시 제거하고 새 교회 데이터를 로드한다', () async {
    final fixture = createFixture();
    await fixture.state.signIn(
      loginId: 'staff@church.app',
      password: 'test1234',
    );
    final memberships = fixture.state.currentUser!.approvedMemberships;
    await fixture.state.activateChurch(memberships.first);
    final firstChurchId = fixture.state.homeContent!.live!.churchId;

    final switching = fixture.state.activateChurch(memberships.last);
    expect(fixture.state.homeContent, isNull);
    await switching;

    expect(
      fixture.state.homeContent!.live!.churchId,
      memberships.last.church.id,
    );
    expect(fixture.state.homeContent!.live!.churchId, isNot(firstChurchId));
  });

  test('live.manage permission은 알려진 권한으로 안전하게 파싱된다', () {
    expect(AppPermission.fromCode('live.manage'), AppPermission.liveManage);
    expect(AppPermission.fromCode('future.permission'), isNull);
  });

  testWidgets('관리 메뉴는 schedule.manage와 live.manage 권한별로 노출된다', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final fixture = createFixture();
    final user = fixture.store.userById('user-c')!;
    fixture.state
      ..currentUser = user
      ..activeMembership = user.approvedMemberships.first
      ..status = AppSessionStatus.authenticated;

    await tester.pumpWidget(
      AppScope(
        state: fixture.state,
        child: const MaterialApp(home: MoreScreen()),
      ),
    );
    expect(find.text('직원 관리자'), findsOneWidget);
    expect(find.text('하늘문교회'), findsAtLeastNWidgets(1));
    expect(find.text('교회 관리'), findsNothing);
    expect(find.text('예배 일정 관리'), findsNothing);
    expect(find.text('LIVE 방송 관리'), findsNothing);
    expect(find.text('팝업공지 관리'), findsNothing);

    fixture.state.toggleRuntimePermission(AppPermission.scheduleManage);
    await tester.pump();
    expect(find.text('예배 일정 관리'), findsOneWidget);
    expect(find.text('LIVE 방송 관리'), findsNothing);

    fixture.state.toggleRuntimePermission(AppPermission.liveManage);
    await tester.pump();
    expect(find.text('LIVE 방송 관리'), findsOneWidget);

    fixture.state.toggleRuntimePermission(AppPermission.popupNoticeManage);
    await tester.pump();
    expect(find.text('팝업공지 관리'), findsOneWidget);

    fixture.state.toggleRuntimePermission(AppPermission.popupNoticeManage);
    await tester.pump();
    expect(find.text('팝업공지 관리'), findsNothing);

    fixture.state.toggleRuntimePermission(AppPermission.scheduleManage);
    await tester.pump();
    expect(find.text('예배 일정 관리'), findsNothing);
    expect(find.text('LIVE 방송 관리'), findsOneWidget);

    fixture.state.toggleRuntimePermission(AppPermission.liveManage);
    await tester.pump();
    expect(find.text('LIVE 방송 관리'), findsNothing);
    expect(find.text('교회 관리'), findsNothing);
  });

  testWidgets('공지사항 메뉴는 notice.view 권한에 따라 노출된다', (tester) async {
    final fixture = createFixture();
    final user = fixture.store.userById('user-c')!;
    final membershipWithoutNoticeView = user.approvedMemberships.last;
    expect(
      membershipWithoutNoticeView.effectivePermissions.contains(
        AppPermission.noticeView,
      ),
      isFalse,
    );
    fixture.state
      ..currentUser = user
      ..activeMembership = membershipWithoutNoticeView
      ..status = AppSessionStatus.authenticated;

    await tester.pumpWidget(
      AppScope(
        state: fixture.state,
        child: const MaterialApp(home: MoreScreen()),
      ),
    );
    expect(find.text('공지사항'), findsNothing);

    fixture.state.toggleRuntimePermission(AppPermission.noticeView);
    await tester.pump();
    expect(find.text('공지사항'), findsOneWidget);
  });

  testWidgets('live.access만으로는 교회 관리나 LIVE 관리 메뉴가 노출되지 않는다', (tester) async {
    final fixture = createFixture();
    final user = fixture.store.userById('user-c')!;
    final memberMembership = user.approvedMemberships.last;
    fixture.state
      ..currentUser = user
      ..activeMembership = memberMembership
      ..status = AppSessionStatus.authenticated;

    await tester.pumpWidget(
      AppScope(
        state: fixture.state,
        child: const MaterialApp(home: MoreScreen()),
      ),
    );

    expect(fixture.state.has(AppPermission.liveAccess), isTrue);
    expect(fixture.state.has(AppPermission.liveManage), isFalse);
    expect(find.text('LIVE 방송 관리'), findsNothing);
    expect(find.text('교회 관리'), findsNothing);
  });

  testWidgets('More의 교회 변경과 로그아웃은 기존 AppState flow를 호출한다', (tester) async {
    final fixture = createFixture();
    final user = fixture.store.userById('user-c')!;
    fixture.state
      ..currentUser = user
      ..activeMembership = user.approvedMemberships.first
      ..status = AppSessionStatus.authenticated;

    await tester.pumpWidget(
      AppScope(
        state: fixture.state,
        child: MaterialApp(
          home: AnimatedBuilder(
            animation: fixture.state,
            builder: (context, _) =>
                fixture.state.status == AppSessionStatus.signedOut
                ? const Scaffold(body: Center(child: Text('signed out')))
                : const MoreScreen(),
          ),
        ),
      ),
    );
    await tester.tap(find.text('교회 변경'));
    expect(fixture.state.status, AppSessionStatus.selectingChurch);

    fixture.state.status = AppSessionStatus.authenticated;
    await tester.tap(find.text('로그아웃'));
    await tester.pump();
    expect(fixture.state.status, AppSessionStatus.signedOut);
    expect(find.text('signed out'), findsOneWidget);
  });

  testWidgets('더보기는 일반 viewport에서 본문을 스크롤하지 않는다', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final fixture = createFixture();
    final user = fixture.store.userById('user-b')!;
    fixture.state
      ..currentUser = user
      ..activeMembership = user.approvedMemberships.single
      ..status = AppSessionStatus.authenticated;

    await tester.pumpWidget(
      AppScope(
        state: fixture.state,
        child: const MaterialApp(home: MoreScreen()),
      ),
    );

    final scrollable = tester.state<ScrollableState>(find.byType(Scrollable));
    expect(scrollable.position.maxScrollExtent, 0);
    await tester.drag(find.byType(Scrollable), const Offset(0, -120));
    await tester.pump();
    expect(scrollable.position.pixels, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('더보기는 작은 viewport에서 본문을 스크롤한다', (tester) async {
    tester.view.physicalSize = const Size(320, 360);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final fixture = createFixture();
    final user = fixture.store.userById('user-b')!;
    fixture.state
      ..currentUser = user
      ..activeMembership = user.approvedMemberships.single
      ..status = AppSessionStatus.authenticated;

    await tester.pumpWidget(
      AppScope(
        state: fixture.state,
        child: const MaterialApp(home: MoreScreen()),
      ),
    );

    final scrollable = tester.state<ScrollableState>(find.byType(Scrollable));
    expect(scrollable.position.maxScrollExtent, greaterThan(0));
    await tester.drag(find.byType(Scrollable), const Offset(0, -120));
    await tester.pump();
    expect(scrollable.position.pixels, greaterThan(0));
    expect(tester.takeException(), isNull);
  });

  test('Case 6: Role Permission에 추가와 제외를 반영한다', () async {
    final fixture = createFixture();
    final auth = MockAuthRepository(fixture.store);
    final repository = MockMembershipRepository(fixture.store);
    final user = await auth.register(
      const RegisterRequest(
        name: '권한 테스트',
        loginId: 'override@test.app',
        password: '123456',
      ),
    );
    final pending = await repository.requestJoin(
      userId: user.id,
      churchId: 'sky-gate',
    );
    final approved = await repository.approve(
      churchId: pending.church.id,
      membershipId: pending.id,
      role: MockAppDataStore.memberRole,
      addedPermissions: {AppPermission.mediaAudioView},
      excludedPermissions: {AppPermission.vodView},
    );
    expect(approved.effectivePermissions, {
      AppPermission.liveAccess,
      AppPermission.mediaAudioView,
    });
    expect(
      NavigationPolicy.available(approved.effectivePermissions)
          .map((item) => item.label),
      ['홈', '음성', '더보기'],
    );
  });

  test('Case 7: pending Membership은 권한 없이 LIVE 비밀번호로 입장한다', () async {
    final fixture = createFixture();
    await fixture.state.register(
      name: '대기 테스트',
      loginId: 'pending@test.app',
      password: '123456',
    );
    final pending = await fixture.state.requestJoin(
      fixture.state.churches.first,
      onboarding: true,
    );
    expect(pending!.effectivePermissions, isEmpty);
    expect(fixture.state.has(AppPermission.liveAccess), isFalse);
    final grant = await fixture.state.liveAccessService.verifyPassword(
      liveId: 'pending-live',
      password: '123456',
    );
    expect(grant?.liveId, 'pending-live');
  });

  test('Case 8: 기존 User A/B/C 내비게이션 정책이 유지된다', () async {
    final fixture = createFixture();
    await fixture.state.signIn(loginId: 'new@church.app', password: 'test1234');
    await fixture.state.activateChurch(
      fixture.state.currentUser!.approvedMemberships.first,
    );
    expect(
      NavigationPolicy.available(fixture.state.effectivePermissions)
          .map((item) => item.label),
      ['홈', '더보기'],
    );
    await fixture.state.signOut();
    await fixture.state.signIn(
      loginId: 'member@church.app',
      password: 'test1234',
    );
    expect(
      NavigationPolicy.available(fixture.state.effectivePermissions)
          .map((item) => item.label),
      ['홈', '영상', '더보기'],
    );
    await fixture.state.signOut();
    await fixture.state.signIn(
      loginId: 'staff@church.app',
      password: 'test1234',
    );
    await fixture.state.activateChurch(
      fixture.state.currentUser!.approvedMemberships.first,
    );
    expect(
      NavigationPolicy.available(fixture.state.effectivePermissions)
          .map((item) => item.label),
      ['홈', '영상', '음성', '업무', '더보기'],
    );
  });

  test('Effective Permission 공식과 중복 이메일 검증을 유지한다', () async {
    expect(
      EffectivePermission.calculate(
        rolePermissions: {AppPermission.liveAccess, AppPermission.vodView},
        addedPermissions: {AppPermission.mediaAudioView},
        excludedPermissions: {AppPermission.vodView},
      ),
      {AppPermission.liveAccess, AppPermission.mediaAudioView},
    );
    final store = MockAppDataStore();
    final auth = MockAuthRepository(store);
    expect(
      () => auth.register(
        const RegisterRequest(
          name: '중복',
          loginId: 'member@church.app',
          password: '123456',
        ),
      ),
      throwsA(isA<AuthException>()),
    );
  });
}
