import 'package:flutter/material.dart';

import '../../../app/app_scope.dart';
import '../../../core/theme/app_theme.dart';
import 'join_church_selection_screen.dart';
import 'membership_status_view.dart';

class MembershipStatusScreen extends StatelessWidget {
  const MembershipStatusScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final memberships = state.currentUser!.memberships;
    return Scaffold(
      appBar: AppBar(
        title: const Text('교회 가입 현황'),
        backgroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          if (memberships.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(22),
                child: Text('아직 가입 신청한 교회가 없습니다.'),
              ),
            )
          else
            ...memberships.map(
              (membership) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                membership.church.name,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: membership.status.background,
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: Text(
                                membership.status.label,
                                style: TextStyle(
                                  color: membership.status.color,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (membership.isApproved) ...[
                          const SizedBox(height: 8),
                          Text(
                            membership.roleName,
                            style: const TextStyle(color: AppTheme.muted),
                          ),
                          if (state.activeMembership?.id != membership.id) ...[
                            const SizedBox(height: 14),
                            OutlinedButton(
                              onPressed: () async {
                                await state.activateChurch(membership);
                                if (context.mounted)
                                  Navigator.of(context).pop();
                              },
                              child: const Text('이 교회 이용하기'),
                            ),
                          ],
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          if (state.joinableChurches.isNotEmpty) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) =>
                      const JoinChurchSelectionScreen(onboarding: false),
                ),
              ),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(Icons.add_rounded),
              label: const Text('다른 교회 가입 신청'),
            ),
          ],
          const SizedBox(height: 16),
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
