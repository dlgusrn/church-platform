import 'package:flutter/material.dart';

import '../../../app/app_scope.dart';
import '../../../core/theme/app_tokens.dart';
import 'church_ui_components.dart';

class ChurchSelectionScreen extends StatelessWidget {
  const ChurchSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final user = state.currentUser!;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.pageHorizontal,
            28,
            AppSpacing.pageHorizontal,
            24,
          ),
          children: [
            if (state.activeMembership != null)
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  tooltip: '이전 화면',
                  onPressed: state.cancelChurchSelection,
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
              ),
            const SizedBox(height: 28),
            Text('소속 교회 선택', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: AppSpacing.sm),
            Text(
              '${user.name}님, 이용할 교회를 선택해주세요.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.xl),
            ...user.approvedMemberships.map(
              (membership) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: ChurchCard(
                  name: membership.church.name,
                  subtitle: membership.roleName,
                  selected: state.activeMembership?.id == membership.id,
                  onTap: () => state.activateChurch(membership),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            TextButton.icon(
              onPressed: state.signOut,
              icon: const Icon(Icons.logout_rounded),
              label: const Text('다른 계정으로 로그인'),
            ),
          ],
        ),
      ),
    );
  }
}
