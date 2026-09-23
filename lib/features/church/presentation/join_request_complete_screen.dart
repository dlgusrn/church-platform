import 'package:flutter/material.dart';

import '../../../app/app_scope.dart';
import '../../../app/app_state.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../shared/models/user.dart';
import '../../../shared/widgets/overflow_only_scroll_physics.dart';
import 'church_ui_components.dart';

class JoinRequestCompleteScreen extends StatefulWidget {
  const JoinRequestCompleteScreen({super.key, required this.onboarding});
  final bool onboarding;

  @override
  State<JoinRequestCompleteScreen> createState() =>
      _JoinRequestCompleteScreenState();
}

class _JoinRequestCompleteScreenState extends State<JoinRequestCompleteScreen> {
  bool _checkingApproval = false;
  String? _approvalMessage;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final membership = state.lastRequestedMembership!;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            physics: const OverflowOnlyScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.pageHorizontal,
                    44,
                    AppSpacing.pageHorizontal,
                    28,
                  ),
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
                      if (_approvalMessage != null) ...[
                        const SizedBox(height: AppSpacing.md),
                        Semantics(
                          liveRegion: true,
                          child: Text(
                            _approvalMessage!,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      ],
                      const Spacer(flex: 2),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(
          AppSpacing.pageHorizontal,
          0,
          AppSpacing.pageHorizontal,
          AppSpacing.md,
        ),
        child: SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _checkingApproval
                ? null
                : () async {
                    if (!widget.onboarding && state.activeMembership != null) {
                      Navigator.of(context).pop();
                      return;
                    }
                    setState(() => _checkingApproval = true);
                    final result = await state.checkPendingMembershipApproval();
                    if (!mounted) return;
                    setState(() {
                      _checkingApproval = false;
                      _approvalMessage = switch (result) {
                        PendingMembershipCheckResult.pending =>
                          '아직 승인 대기 중입니다. 관리자 승인 후 다시 확인해주세요.',
                        PendingMembershipCheckResult.error =>
                          state.membershipError ??
                              '승인 상태를 확인하지 못했습니다. 다시 시도해주세요.',
                        _ => null,
                      };
                    });
                  },
            child: Text(
              widget.onboarding || state.activeMembership == null
                  ? '승인 여부 확인'
                  : '확인',
            ),
          ),
        ),
      ),
    );
  }
}
