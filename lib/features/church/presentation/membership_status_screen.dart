import 'package:flutter/material.dart';

import '../../../app/app_scope.dart';
import '../../../core/theme/app_tokens.dart';
import 'church_ui_components.dart';
import 'join_church_selection_screen.dart';

class MembershipStatusScreen extends StatelessWidget {
  const MembershipStatusScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final memberships = state.currentUser!.memberships;
    return Scaffold(
      appBar: AppBar(title: const Text('교회 가입 현황')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.pageHorizontal,
          AppSpacing.md,
          AppSpacing.pageHorizontal,
          32,
        ),
        children: [
          Text('내 소속 교회', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '승인된 교회만 선택하여 이용할 수 있습니다.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.xl),
          if (memberships.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.cardPadding),
                child: Text('아직 가입 신청한 교회가 없습니다.'),
              ),
            )
          else
            ...memberships.map(
              (membership) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: ChurchCard(
                  name: membership.church.name,
                  subtitle: membership.isApproved
                      ? membership.roleName
                      : '선택하려면 관리자 승인이 필요합니다.',
                  selected: state.activeMembership?.id == membership.id,
                  enabled: membership.isApproved,
                  onTap:
                      membership.isApproved &&
                          state.activeMembership?.id != membership.id
                      ? () async {
                          await state.activateChurch(membership);
                          if (context.mounted) Navigator.of(context).pop();
                        }
                      : null,
                  trailing: MembershipStatusBadge(status: membership.status),
                ),
              ),
            ),
          if (state.joinableChurches.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) =>
                      const JoinChurchSelectionScreen(onboarding: false),
                ),
              ),
              icon: const Icon(Icons.add_rounded),
              label: const Text('다른 교회 가입 신청'),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          TextButton.icon(
            onPressed: state.signOut,
            icon: const Icon(Icons.logout_rounded),
            label: const Text('로그아웃'),
          ),
        ],
      ),
    );
  }
}
