import 'package:flutter/material.dart';

import '../../../app/app_scope.dart';
import '../../../core/theme/app_theme.dart';
import 'join_request_complete_screen.dart';

class JoinChurchSelectionScreen extends StatelessWidget {
  const JoinChurchSelectionScreen({super.key, required this.onboarding});
  final bool onboarding;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final churches = state.joinableChurches;
    return Scaffold(
      appBar: onboarding
          ? null
          : AppBar(
              title: const Text('다른 교회 가입'),
              backgroundColor: Colors.white,
            ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 40, 24, 32),
          children: [
            Text(
              '가입할 교회를\n선택해주세요',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 10),
            const Text(
              '가입 신청은 교회 관리자의 승인 후 완료됩니다.',
              style: TextStyle(color: AppTheme.muted),
            ),
            const SizedBox(height: 30),
            if (churches.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(22),
                  child: Text('현재 추가로 신청할 수 있는 교회가 없습니다.'),
                ),
              )
            else
              ...churches.map(
                (church) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Material(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(18),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () async {
                        final membership = await state.requestJoin(
                          church,
                          onboarding: onboarding,
                        );
                        if (!context.mounted ||
                            membership == null ||
                            onboarding)
                          return;
                        await Navigator.of(context).pushReplacement(
                          MaterialPageRoute<void>(
                            builder: (_) => const JoinRequestCompleteScreen(
                              onboarding: false,
                            ),
                          ),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(
                                Icons.church_outlined,
                                color: AppTheme.primary,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Text(
                                church.name,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                            const Icon(Icons.chevron_right_rounded),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            if (state.membershipError != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  state.membershipError!,
                  style: const TextStyle(color: Colors.redAccent),
                ),
              ),
            if (onboarding) ...[
              const SizedBox(height: 18),
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
