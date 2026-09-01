import 'package:flutter/material.dart';

import '../../../app/app_scope.dart';
import '../../../core/theme/app_theme.dart';

class JoinRequestCompleteScreen extends StatelessWidget {
  const JoinRequestCompleteScreen({super.key, required this.onboarding});
  final bool onboarding;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final membership = state.lastRequestedMembership!;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 44, 24, 28),
          child: Column(
            children: [
              const Spacer(),
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: const Color(0xFFE4EFEB),
                  borderRadius: BorderRadius.circular(26),
                ),
                child: const Icon(
                  Icons.mark_email_read_outlined,
                  size: 36,
                  color: AppTheme.primary,
                ),
              ),
              const SizedBox(height: 28),
              Text(
                '가입 신청이 완료되었습니다',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 12),
              Text(
                membership.church.name,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 10),
              const Text(
                '관리자 승인 후\n교회의 콘텐츠와 기능을 이용할 수 있습니다.',
                textAlign: TextAlign.center,
                style: TextStyle(height: 1.55, color: AppTheme.muted),
              ),
              const SizedBox(height: 30),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          '현재 상태',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF2D8),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          '승인 대기',
                          style: TextStyle(
                            color: Color(0xFF9B6814),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(flex: 2),
              FilledButton(
                onPressed: () async {
                  if (onboarding || state.activeMembership == null) {
                    await state.continueFromApproval();
                  } else if (context.mounted) {
                    Navigator.of(context).pop();
                  }
                },
                child: const Text('확인'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
