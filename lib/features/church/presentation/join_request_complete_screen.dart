import 'package:flutter/material.dart';

import '../../../app/app_scope.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../shared/models/user.dart';
import 'church_ui_components.dart';

class JoinRequestCompleteScreen extends StatelessWidget {
  const JoinRequestCompleteScreen({super.key, required this.onboarding});
  final bool onboarding;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final membership = state.lastRequestedMembership!;
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.pageHorizontal,
              44,
              AppSpacing.pageHorizontal,
              28,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Column(
                  children: [
                    const Spacer(),
                    Container(
                      width: 76,
                      height: 76,
                      decoration: const BoxDecoration(
                        color: AppColors.primarySoft,
                        borderRadius: AppRadii.card,
                      ),
                      child: const Icon(
                        Icons.mark_email_read_outlined,
                        size: 36,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    Text(
                      '가입 신청이 완료되었습니다',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      membership.church.name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      '관리자 승인 후\n교회의 콘텐츠와 기능을 이용할 수 있습니다.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 30),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.cardPadding),
                        child: Row(
                          children: const [
                            Expanded(
                              child: Text(
                                '현재 상태',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ),
                            MembershipStatusBadge(
                              status: MembershipStatus.pending,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Spacer(flex: 2),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () async {
                          if (onboarding || state.activeMembership == null) {
                            await state.continueFromApproval();
                          } else if (context.mounted) {
                            Navigator.of(context).pop();
                          }
                        },
                        child: const Text('확인'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
