import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/church/presentation/church_selection_screen.dart';
import '../features/church/presentation/join_church_selection_screen.dart';
import '../features/church/presentation/join_request_complete_screen.dart';
import '../features/church/presentation/membership_status_screen.dart';
import 'app_scope.dart';
import 'app_state.dart';
import 'main_shell.dart';

class ChurchApp extends StatelessWidget {
  const ChurchApp({super.key, required this.appState});
  final AppState appState;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      state: appState,
      child: MaterialApp(
        title: '교회 통합 앱',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: AnimatedBuilder(
          animation: appState,
          builder: (context, _) => switch (appState.status) {
            AppSessionStatus.signedOut => const LoginScreen(),
            AppSessionStatus.selectingJoinChurch =>
              const JoinChurchSelectionScreen(onboarding: true),
            AppSessionStatus.approvalPending => const JoinRequestCompleteScreen(
              onboarding: true,
            ),
            AppSessionStatus.membershipStatus => const MembershipStatusScreen(),
            AppSessionStatus.selectingChurch => const ChurchSelectionScreen(),
            AppSessionStatus.authenticated => const MainShell(),
          },
        ),
      ),
    );
  }
}
