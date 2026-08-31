import 'package:church_app/app/app_state.dart';
import 'package:church_app/core/auth/mock_auth_repository.dart';
import 'package:church_app/core/navigation/app_destination.dart';
import 'package:church_app/core/permission/app_permission.dart';
import 'package:church_app/core/permission/effective_permission.dart';
import 'package:church_app/features/home/data/mock_home_repository.dart';
import 'package:church_app/features/live/data/mock_live_access_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  AppState createState() => AppState(
    authRepository: MockAuthRepository(),
    homeRepository: MockHomeRepository(),
    liveAccessService: MockLiveAccessService(),
  );

  test('Role 기본 + 사용자 추가 - 사용자 제외로 Effective Permission을 계산한다', () {
    final result = EffectivePermission.calculate(
      rolePermissions: {AppPermission.vodView, AppPermission.noticeView},
      addedPermissions: {AppPermission.mediaAudioView},
      excludedPermissions: {AppPermission.noticeView},
    );
    expect(result, {AppPermission.vodView, AppPermission.mediaAudioView});
  });

  test('Case 1: 신규 사용자는 홈과 더보기만 노출된다', () async {
    final state = createState();
    await state.signIn(loginId: 'new@church.app', password: 'test1234');
    expect(state.status, AppSessionStatus.selectingChurch);
    await state.activateChurch(state.currentUser!.memberships.first);
    expect(state.effectivePermissions, isEmpty);
    expect(
      NavigationPolicy.available(state.effectivePermissions)
          .map((item) => item.label),
      ['홈', '더보기'],
    );
    expect(state.homeContent?.live, isNotNull);
    expect(state.has(AppPermission.vodView), isFalse);
  });

  test('Case 2: 성도는 홈, 영상, 더보기가 노출된다', () async {
    final state = createState();
    await state.signIn(loginId: 'member@church.app', password: 'test1234');
    expect(state.status, AppSessionStatus.authenticated);
    expect(
      NavigationPolicy.available(state.effectivePermissions)
          .map((item) => item.label),
      ['홈', '영상', '더보기'],
    );
    expect(state.has(AppPermission.liveAccess), isTrue);
    expect(state.has(AppPermission.vodView), isTrue);
  });

  test('Case 3: 직원은 전체 하단 메뉴가 노출된다', () async {
    final state = createState();
    await state.signIn(loginId: 'staff@church.app', password: 'test1234');
    await state.activateChurch(state.currentUser!.memberships.first);
    expect(
      NavigationPolicy.available(state.effectivePermissions)
          .map((item) => item.label),
      ['홈', '영상', '음성', '업무', '더보기'],
    );
  });

  test('Case 4: 실행 중 권한 변경이 메뉴 정책에 즉시 반영된다', () async {
    final state = createState();
    await state.signIn(loginId: 'new@church.app', password: 'test1234');
    await state.activateChurch(state.currentUser!.memberships.first);
    state.toggleRuntimePermission(AppPermission.vodView);
    state.toggleRuntimePermission(AppPermission.mediaAudioView);
    state.toggleRuntimePermission(AppPermission.noticeView);
    expect(
      NavigationPolicy.available(state.effectivePermissions)
          .map((item) => item.label),
      ['홈', '영상', '음성', '업무', '더보기'],
    );
  });

  test('Case 5: 교회 변경 시 이전 교회의 권한과 런타임 권한이 남지 않는다', () async {
    final state = createState();
    await state.signIn(loginId: 'staff@church.app', password: 'test1234');
    await state.activateChurch(state.currentUser!.memberships.first);
    state.toggleRuntimePermission(AppPermission.churchManage);
    await state.activateChurch(state.currentUser!.memberships.last);
    expect(state.activeMembership!.church.id, 'bethel');
    expect(state.has(AppPermission.mediaAudioView), isFalse);
    expect(state.has(AppPermission.churchManage), isFalse);
    expect(state.has(AppPermission.liveAccess), isTrue);
  });

  test('Case 6: 로그아웃 후 사용자, 교회, 권한 상태가 초기화된다', () async {
    final state = createState();
    await state.signIn(loginId: 'member@church.app', password: 'test1234');
    await state.signOut();
    expect(state.status, AppSessionStatus.signedOut);
    expect(state.currentUser, isNull);
    expect(state.activeMembership, isNull);
    expect(state.effectivePermissions, isEmpty);
    expect(state.homeContent, isNull);
  });

  test('LIVE 비밀번호 성공과 실패를 서비스 계층에서 검증한다', () async {
    final service = MockLiveAccessService();
    expect(
      await service.verifyPassword(liveId: 'live-1', password: '000000'),
      isNull,
    );
    final grant = await service.verifyPassword(
      liveId: 'live-1',
      password: '123456',
    );
    expect(grant?.liveId, 'live-1');
  });
}
