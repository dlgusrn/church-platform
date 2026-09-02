import 'package:church_app/app/app_state.dart';
import 'package:church_app/app/app_scope.dart';
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
import 'package:church_app/features/live/data/mock_live_access_service.dart';
import 'package:church_app/features/more/presentation/more_screen.dart';
import 'package:church_app/shared/models/user.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

({AppState state, MockAppDataStore store}) createFixture() {
  final store = MockAppDataStore();
  return (
    store: store,
    state: AppState(
      authRepository: MockAuthRepository(store),
      churchRepository: MockChurchRepository(store),
      membershipRepository: MockMembershipRepository(store),
      roleRepository: MockRoleRepository(store),
      homeRepository: MockHomeRepository(),
      liveAccessService: MockLiveAccessService(),
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
    expect(find.text('예배 일정 관리'), findsNothing);
    expect(find.text('LIVE 방송 관리'), findsNothing);

    fixture.state.toggleRuntimePermission(AppPermission.scheduleManage);
    await tester.pump();
    expect(find.text('예배 일정 관리'), findsOneWidget);
    expect(find.text('LIVE 방송 관리'), findsNothing);

    fixture.state.toggleRuntimePermission(AppPermission.liveManage);
    await tester.pump();
    expect(find.text('LIVE 방송 관리'), findsOneWidget);

    fixture.state.toggleRuntimePermission(AppPermission.scheduleManage);
    await tester.pump();
    expect(find.text('예배 일정 관리'), findsNothing);
    expect(find.text('LIVE 방송 관리'), findsOneWidget);

    fixture.state.toggleRuntimePermission(AppPermission.liveManage);
    await tester.pump();
    expect(find.text('LIVE 방송 관리'), findsNothing);
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
