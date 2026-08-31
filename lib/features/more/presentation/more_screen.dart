import 'package:flutter/material.dart';

import '../../../app/app_scope.dart';
import '../../../core/permission/app_permission.dart';
import '../../../core/theme/app_theme.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final membership = state.activeMembership!;
    final canSwitch = state.currentUser!.memberships.length > 1;
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
                          '${membership.church.name} · ${membership.roleName}',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (canSwitch) ...[
            const SizedBox(height: 12),
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
          const SizedBox(height: 28),
          Text(
            '현재 Effective Permission',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 10),
          if (permissions.isEmpty)
          const Text('현재 기본 기능만 이용 중입니다.', style: TextStyle(color: AppTheme.muted))
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
          const SizedBox(height: 28),
          Text(
            '실행 중 권한 변경 테스트',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          const Text(
            '서버에서 권한이 갱신된 상황을 시뮬레이션합니다.',
            style: TextStyle(color: AppTheme.muted, fontSize: 12),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
            title: const Text('vod.view 임시 추가'),
            value: state.has(AppPermission.vodView),
            onChanged:
                membership.effectivePermissions.contains(AppPermission.vodView)
                ? null
                : (_) => state.toggleRuntimePermission(AppPermission.vodView),
          ),
          SwitchListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
            title: const Text('media.audio.view 임시 추가'),
            value: state.has(AppPermission.mediaAudioView),
            onChanged:
                membership.effectivePermissions.contains(
                  AppPermission.mediaAudioView,
                )
                ? null
                : (_) => state.toggleRuntimePermission(
                    AppPermission.mediaAudioView,
                  ),
          ),
          SwitchListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
            title: const Text('notice.view 임시 추가'),
            value: state.has(AppPermission.noticeView),
            onChanged:
                membership.effectivePermissions.contains(
                  AppPermission.noticeView,
                )
                ? null
                : (_) =>
                      state.toggleRuntimePermission(AppPermission.noticeView),
          ),
          const SizedBox(height: 16),
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
