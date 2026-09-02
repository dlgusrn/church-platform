import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../app/app_scope.dart';
import '../../../core/permission/app_permission.dart';
import '../../../core/network/api_config.dart';
import '../../../core/theme/app_theme.dart';
import '../../church/presentation/membership_admin_screen.dart';
import '../../church/presentation/membership_status_screen.dart';
import '../../church/presentation/membership_status_view.dart';
import '../../home/presentation/live_broadcast_admin_screen.dart';
import '../../home/presentation/worship_schedule_admin_screen.dart';
import '../../notices/presentation/notices_screen.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final membership = state.currentChurchMembership!;
    final canSwitch = state.approvedMemberships.length > 1;
    final permissions = state.effectivePermissions.toList()
      ..sort((a, b) => a.code.compareTo(b.code));
    return Scaffold(
      appBar: AppBar(title: const Text('더보기'), backgroundColor: Colors.white),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: const Color(0xFFE4EFEB),
                    child: Text(
                      state.currentUser!.name.characters.first,
                      style: const TextStyle(
                        color: AppTheme.primary,
                        fontWeight: FontWeight.w800,
                        fontSize: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          state.currentUser!.name,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${membership.church.name} · ${membership.isApproved ? membership.roleName : membership.status.label}',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          ListTile(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const MembershipStatusScreen(),
              ),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            tileColor: AppTheme.surface,
            leading: const Icon(
              Icons.how_to_reg_outlined,
              color: AppTheme.primary,
            ),
            title: const Text(
              '교회 가입 현황',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            trailing: const Icon(Icons.chevron_right_rounded),
          ),
          if (canSwitch) ...[
            const SizedBox(height: 10),
            ListTile(
              onTap: state.requestChurchSelection,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              tileColor: AppTheme.surface,
              leading: const Icon(
                Icons.swap_horiz_rounded,
                color: AppTheme.primary,
              ),
              title: const Text(
                '교회 변경',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
            ),
          ],
          if (state.has(AppPermission.noticeView)) ...[
            const SizedBox(height: 10),
            _ManagementTile(
              icon: Icons.campaign_outlined,
              title: '공지사항',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const NoticesScreen()),
              ),
            ),
          ],
          if (state.hasAny({
            AppPermission.scheduleManage,
            AppPermission.liveManage,
          })) ...[
            const SizedBox(height: 28),
            Text('교회 관리', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            if (state.has(AppPermission.scheduleManage))
              _ManagementTile(
                icon: Icons.event_note_outlined,
                title: '예배 일정 관리',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const WorshipScheduleAdminScreen(),
                  ),
                ),
              ),
            if (state.has(AppPermission.liveManage)) ...[
              if (state.has(AppPermission.scheduleManage))
                const SizedBox(height: 10),
              _ManagementTile(
                icon: Icons.live_tv_outlined,
                title: 'LIVE 방송 관리',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const LiveBroadcastAdminScreen(),
                  ),
                ),
              ),
            ],
          ],
          if (kDebugMode &&
              state.hasAny({
                AppPermission.memberView,
                AppPermission.memberManage,
                AppPermission.roleView,
                AppPermission.permissionManage,
              })) ...[
            const SizedBox(height: 28),
            Text('개발 도구', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            ListTile(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const MembershipAdminScreen(),
                ),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              tileColor: const Color(0xFFF0F3F2),
              leading: const Icon(
                Icons.admin_panel_settings_outlined,
                color: AppTheme.primary,
              ),
              title: const Text(
                '가입 승인 관리',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
            ),
            const SizedBox(height: 22),
            Text(
              '현재 Effective Permission',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 10),
            if (permissions.isEmpty)
              const Text(
                '현재 기본 기능만 이용 중입니다.',
                style: TextStyle(color: AppTheme.muted),
              )
            else
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: [
                  for (final permission in permissions)
                    Chip(
                      label: Text(
                        permission.code,
                        style: const TextStyle(fontSize: 11),
                      ),
                      side: BorderSide.none,
                      backgroundColor: AppTheme.surface,
                    ),
                ],
              ),
            if (membership.isApproved && ApiConfig.useMockRepositories) ...[
              const SizedBox(height: 22),
              Text(
                '실행 중 권한 변경 테스트',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              const Text(
                '서버에서 권한이 갱신된 상황을 시뮬레이션합니다.',
                style: TextStyle(color: AppTheme.muted, fontSize: 12),
              ),
              _PermissionSwitch(permission: AppPermission.vodView),
              _PermissionSwitch(permission: AppPermission.mediaAudioView),
              _PermissionSwitch(permission: AppPermission.noticeView),
            ],
          ],
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: state.signOut,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              foregroundColor: Colors.redAccent,
              side: const BorderSide(color: Color(0xFFFFD5D5)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: const Icon(Icons.logout_rounded),
            label: const Text('로그아웃'),
          ),
        ],
      ),
    );
  }
}

class _ManagementTile extends StatelessWidget {
  const _ManagementTile({
    required this.icon,
    required this.title,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    onTap: onTap,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    tileColor: AppTheme.surface,
    leading: Icon(icon, color: AppTheme.primary),
    title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
    trailing: const Icon(Icons.chevron_right_rounded),
  );
}

class _PermissionSwitch extends StatelessWidget {
  const _PermissionSwitch({required this.permission});
  final AppPermission permission;
  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final baseHas = state.activeMembership!.effectivePermissions.contains(
      permission,
    );
    return SwitchListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      title: Text('${permission.code} 임시 추가'),
      value: state.has(permission),
      onChanged: baseHas
          ? null
          : (_) => state.toggleRuntimePermission(permission),
    );
  }
}
