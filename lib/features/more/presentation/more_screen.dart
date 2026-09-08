import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../app/app_scope.dart';
import '../../../core/network/api_config.dart';
import '../../../core/permission/app_permission.dart';
import '../../../core/theme/app_tokens.dart';
import '../../church/presentation/membership_admin_screen.dart';
import '../../church/presentation/membership_status_screen.dart';
import '../../church/presentation/membership_status_view.dart';
import '../../home/presentation/live_broadcast_admin_screen.dart';
import '../../home/presentation/worship_schedule_admin_screen.dart';
import '../../notices/presentation/notices_screen.dart';
import '../../popup_notices/presentation/popup_notice_admin_screen.dart';
import '../../video/presentation/youtube_registration_screen.dart';
import '../../video/presentation/synology_import_screen.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final membership = state.currentChurchMembership!;
    final canSwitch = state.approvedMemberships.length > 1;
    final permissions = state.effectivePermissions.toList()
      ..sort((a, b) => a.code.compareTo(b.code));
    final hasManagement = state.hasAny({
      AppPermission.memberManage,
      AppPermission.scheduleManage,
      AppPermission.liveManage,
      AppPermission.popupNoticeManage,
      AppPermission.mediaVideoManage,
    });
    final hasDeveloperTools = state.hasAny({
      AppPermission.memberView,
      AppPermission.memberManage,
      AppPermission.roleView,
      AppPermission.permissionManage,
    });

    return Scaffold(
      appBar: AppBar(title: const Text('더보기')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.pageHorizontal,
          AppSpacing.md,
          AppSpacing.pageHorizontal,
          32,
        ),
        children: [
          _ProfileSummary(
            name: state.currentUser!.name,
            churchName: membership.church.name,
            roleOrStatus: membership.isApproved
                ? membership.roleName
                : membership.status.label,
          ),
          const SizedBox(height: AppSpacing.xl),
          _MoreSection(
            title: '일반',
            child: _MoreMenuGroup(
              children: [
                _MoreMenuItem(
                  icon: Icons.how_to_reg_outlined,
                  title: '교회 가입 현황',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const MembershipStatusScreen(),
                    ),
                  ),
                ),
                if (canSwitch)
                  _MoreMenuItem(
                    icon: Icons.swap_horiz_rounded,
                    title: '교회 변경',
                    subtitle: membership.church.name,
                    onTap: state.requestChurchSelection,
                  ),
                if (state.has(AppPermission.noticeView))
                  _MoreMenuItem(
                    icon: Icons.campaign_outlined,
                    title: '공지사항',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const NoticesScreen(),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (hasManagement) ...[
            const SizedBox(height: AppSpacing.sectionGap),
            _MoreSection(
              title: '교회 관리',
              child: _MoreMenuGroup(
                children: [
                  if (state.has(AppPermission.memberManage))
                    _MoreMenuItem(
                      icon: Icons.people_outline_rounded,
                      title: '회원 및 가입 승인 관리',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const MembershipAdminScreen(),
                        ),
                      ),
                    ),
                  if (state.has(AppPermission.scheduleManage))
                    _MoreMenuItem(
                      icon: Icons.event_note_outlined,
                      title: '예배 일정 관리',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const WorshipScheduleAdminScreen(),
                        ),
                      ),
                    ),
                  if (state.has(AppPermission.liveManage))
                    _MoreMenuItem(
                      icon: Icons.live_tv_outlined,
                      title: 'LIVE 방송 관리',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const LiveBroadcastAdminScreen(),
                        ),
                      ),
                    ),
                  if (state.has(AppPermission.popupNoticeManage))
                    _MoreMenuItem(
                      icon: Icons.campaign_outlined,
                      title: '팝업공지 관리',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const PopupNoticeAdminScreen(),
                        ),
                      ),
                    ),
                  if (state.has(AppPermission.mediaVideoManage))
                    _MoreMenuItem(
                      icon: Icons.video_library_outlined,
                      title: '영상 관리',
                      subtitle: 'YouTube 등록 · NAS 영상 가져오기',
                      onTap: () => showModalBottomSheet<void>(
                        context: context,
                        builder: (sheetContext) => SafeArea(
                          child: Wrap(
                            children: [
                              ListTile(
                                title: const Text('YouTube 영상 등록'),
                                onTap: () {
                                  Navigator.pop(sheetContext);
                                  Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) =>
                                          const YouTubeRegistrationScreen(),
                                    ),
                                  );
                                },
                              ),
                              ListTile(
                                title: const Text('NAS 영상 가져오기'),
                                onTap: () {
                                  Navigator.pop(sheetContext);
                                  Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) =>
                                          const SynologyImportScreen(),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
          if (kDebugMode && hasDeveloperTools) ...[
            const SizedBox(height: AppSpacing.sectionGap),
            _DeveloperSection(
              membershipApproved: membership.isApproved,
              permissions: permissions,
            ),
          ],
          const SizedBox(height: 36),
          Semantics(
            button: true,
            label: '로그아웃',
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: state.signOut,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.danger,
                  side: const BorderSide(color: AppColors.danger),
                ),
                icon: const Icon(Icons.logout_rounded),
                label: const Text('로그아웃'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileSummary extends StatelessWidget {
  const _ProfileSummary({
    required this.name,
    required this.churchName,
    required this.roleOrStatus,
  });

  final String name;
  final String churchName;
  final String roleOrStatus;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CircleAvatar(
            radius: 26,
            backgroundColor: AppColors.primarySoft,
            child: Icon(Icons.person_outline_rounded, color: AppColors.primary),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  churchName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  roleOrStatus,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _MoreSection extends StatelessWidget {
  const _MoreSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: AppSpacing.sm),
      child,
    ],
  );
}

class _MoreMenuGroup extends StatelessWidget {
  const _MoreMenuGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: Column(
      children: [
        for (var index = 0; index < children.length; index++) ...[
          children[index],
          if (index < children.length - 1) const Divider(indent: 72, height: 1),
        ],
      ],
    ),
  );
}

class _MoreMenuItem extends StatelessWidget {
  const _MoreMenuItem({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    onTap: onTap,
    minVerticalPadding: AppSpacing.sm,
    leading: Container(
      width: 40,
      height: 40,
      decoration: const BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.all(AppRadii.small),
      ),
      child: Icon(icon, color: AppColors.primary),
    ),
    title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
    subtitle: subtitle == null
        ? null
        : Text(subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis),
    trailing: const ExcludeSemantics(
      child: Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
    ),
  );
}

class _DeveloperSection extends StatelessWidget {
  const _DeveloperSection({
    required this.membershipApproved,
    required this.permissions,
  });

  final bool membershipApproved;
  final List<AppPermission> permissions;

  @override
  Widget build(BuildContext context) => _MoreSection(
    title: '개발 도구',
    child: Card(
      color: AppColors.surfaceMuted,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '현재 Effective Permission',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            if (permissions.isEmpty)
              Text(
                '현재 기본 기능만 이용 중입니다.',
                style: Theme.of(context).textTheme.bodySmall,
              )
            else
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  for (final permission in permissions)
                    Chip(label: Text(permission.code)),
                ],
              ),
            if (membershipApproved && ApiConfig.useMockRepositories) ...[
              const SizedBox(height: AppSpacing.lg),
              Text(
                '실행 중 권한 변경 테스트',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '서버에서 권한이 갱신된 상황을 시뮬레이션합니다.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const _PermissionSwitch(permission: AppPermission.vodView),
              const _PermissionSwitch(permission: AppPermission.mediaAudioView),
              const _PermissionSwitch(permission: AppPermission.noticeView),
            ],
          ],
        ),
      ),
    ),
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
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
      title: Text('${permission.code} 임시 추가'),
      value: state.has(permission),
      onChanged: baseHas
          ? null
          : (_) => state.toggleRuntimePermission(permission),
    );
  }
}
