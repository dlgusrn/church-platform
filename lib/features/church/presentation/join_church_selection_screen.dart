import 'package:flutter/material.dart';

import '../../../app/app_scope.dart';
import '../../../core/theme/app_tokens.dart';
import 'church_ui_components.dart';
import 'join_request_complete_screen.dart';

class JoinChurchSelectionScreen extends StatelessWidget {
  const JoinChurchSelectionScreen({super.key, required this.onboarding});
  final bool onboarding;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final churches = state.joinableChurches;
    return Scaffold(
      appBar: onboarding ? null : AppBar(title: const Text('다른 교회 가입')),
      body: SafeArea(
        top: onboarding,
        child: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.pageHorizontal,
            40,
            AppSpacing.pageHorizontal,
            32,
          ),
          children: [
            Text(
              '가입할 교회를\n선택해주세요',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              '가입 신청은 교회 관리자의 승인 후 완료됩니다.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 30),
            if (churches.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(AppSpacing.cardPadding),
                  child: Text('현재 추가로 신청할 수 있는 교회가 없습니다.'),
                ),
              )
            else
              ...churches.map(
                (church) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: ChurchCard(
                    name: church.name,
                    subtitle: '가입 신청',
                    onTap: () async {
                      final membership = await state.requestJoin(
                        church,
                        onboarding: onboarding,
                      );
                      if (!context.mounted || membership == null || onboarding)
                        return;
                      await Navigator.of(context).pushReplacement(
                        MaterialPageRoute<void>(
                          builder: (_) => const JoinRequestCompleteScreen(
                            onboarding: false,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            if (state.membershipError != null)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    state.membershipError!,
                    style: const TextStyle(color: AppColors.danger),
                  ),
                ),
              ),
            if (onboarding) ...[
              const SizedBox(height: AppSpacing.lg),
              TextButton(
                onPressed: state.signOut,
                child: const Text('나중에 가입하기 · 로그아웃'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
