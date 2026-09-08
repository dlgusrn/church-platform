import 'package:church_app/app/app_scope.dart';
import 'package:church_app/app/app_state.dart';
import 'package:church_app/core/auth/mock_auth_repository.dart';
import 'package:church_app/core/mock/mock_app_data_store.dart';
import 'package:church_app/core/permission/mock_role_repository.dart';
import 'package:church_app/core/theme/app_theme.dart';
import 'package:church_app/features/auth/presentation/login_screen.dart';
import 'package:church_app/features/church/data/mock_church_repository.dart';
import 'package:church_app/features/church/data/mock_membership_repository.dart';
import 'package:church_app/features/church/presentation/church_selection_screen.dart';
import 'package:church_app/features/church/presentation/church_ui_components.dart';
import 'package:church_app/features/church/presentation/membership_status_screen.dart';
import 'package:church_app/features/home/data/mock_home_repository.dart';
import 'package:church_app/features/live/data/mock_live_access_service.dart';
import 'package:church_app/features/notices/data/mock_notice_repository.dart';
import 'package:church_app/shared/models/church.dart';
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
      noticeRepository: MockNoticeRepository(),
    ),
  );
}

Widget appFor(AppState state, Widget child) => AppScope(
  state: state,
  child: MaterialApp(theme: AppTheme.light, home: child),
);

void main() {
  testWidgets('로그인 중에는 중복 submit을 막고 인증 오류를 표시한다', (tester) async {
    final fixture = createFixture();
    await tester.pumpWidget(appFor(fixture.state, const LoginScreen()));

    await tester.enterText(find.byType(TextField).first, 'unknown@church.app');
    await tester.enterText(find.byType(TextField).last, 'wrong-password');
    await tester.tap(find.text('로그인'));
    await tester.pump();

    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);

    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('아이디 또는 비밀번호를 확인해주세요.'), findsOneWidget);
  });

  testWidgets('회원가입 진입은 유지되고 가입 form validation을 수행한다', (tester) async {
    final fixture = createFixture();
    await tester.pumpWidget(appFor(fixture.state, const LoginScreen()));

    await tester.tap(find.text('처음이신가요? 회원가입'));
    await tester.pumpAndSettle();
    expect(find.text('계정을 만들어주세요'), findsOneWidget);

    await tester.tap(find.text('다음'));
    await tester.pump();
    expect(find.text('이름을 입력해주세요.'), findsOneWidget);
  });

  testWidgets('소속 교회 선택은 approved membership만 즉시 선택 대상으로 노출한다', (tester) async {
    final fixture = createFixture();
    final user = fixture.store.userById('user-c')!;
    fixture.state
      ..currentUser = user
      ..status = AppSessionStatus.selectingChurch;

    await tester.pumpWidget(
      appFor(fixture.state, const ChurchSelectionScreen()),
    );
    expect(
      find.byType(ChurchCard),
      findsNWidgets(user.approvedMemberships.length),
    );

    await tester.tap(find.byType(ChurchCard).first);
    await tester.pumpAndSettle();
    expect(
      fixture.state.activeMembership?.id,
      user.approvedMemberships.first.id,
    );
  });

  testWidgets('pending과 rejected membership은 가입 현황에서 상태를 보이고 선택 대상으로 만들지 않는다', (
    tester,
  ) async {
    final fixture = createFixture();
    const church = Church(id: 'church', name: '테스트 교회');
    final pending = ChurchMembership(
      id: 'pending',
      userId: 'user',
      church: church,
      status: MembershipStatus.pending,
      requestedAt: DateTime(2026),
    );
    final rejected = ChurchMembership(
      id: 'rejected',
      userId: 'user',
      church: const Church(id: 'church-2', name: '다른 교회'),
      status: MembershipStatus.rejected,
      requestedAt: DateTime(2026),
    );
    fixture.state
      ..currentUser = AppUser(
        id: 'user',
        name: '테스터',
        loginId: 'test@church.app',
        memberships: [pending, rejected],
      )
      ..status = AppSessionStatus.membershipStatus;

    await tester.pumpWidget(
      appFor(fixture.state, const MembershipStatusScreen()),
    );
    expect(find.text('승인 대기'), findsOneWidget);
    expect(find.text('가입 거절'), findsOneWidget);
    final cards = tester
        .widgetList<ChurchCard>(find.byType(ChurchCard))
        .toList();
    expect(cards.map((card) => card.enabled), everyElement(isFalse));
  });
}
