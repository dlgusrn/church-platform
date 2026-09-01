import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../app/app_scope.dart';
import '../../../core/permission/app_permission.dart';
import '../../../core/permission/app_role.dart';
import '../../../core/permission/effective_permission.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/user.dart';

class MembershipAdminScreen extends StatefulWidget {
  const MembershipAdminScreen({super.key});
  @override
  State<MembershipAdminScreen> createState() => _MembershipAdminScreenState();
}

class _MembershipAdminScreenState extends State<MembershipAdminScreen> {
  late Future<List<ChurchMembership>> _pending;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _pending = AppScope.of(context).membershipRepository
        .getPendingMemberships();
  }

  Future<void> _reload() async {
    final memberships = await AppScope.of(context).membershipRepository
        .getPendingMemberships();
    if (!mounted) return;
    setState(() {
      _pending = Future.value(memberships);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) return const SizedBox.shrink();
    final state = AppScope.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mock 가입 승인 관리'),
        backgroundColor: Colors.white,
      ),
      body: FutureBuilder<List<ChurchMembership>>(
        future: _pending,
        builder: (context, snapshot) {
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());
          final memberships = snapshot.data!;
          if (memberships.isEmpty)
            return const Center(
              child: Text(
                '승인 대기 중인 가입 요청이 없습니다.',
                style: TextStyle(color: AppTheme.muted),
              ),
            );
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            children: [
              Text('신규 가입 요청', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 14),
              ...memberships.map(
                (membership) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: FutureBuilder<AppUser?>(
                        future: state.userForMembership(membership),
                        builder: (context, userSnapshot) => Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              userSnapshot.data?.name ?? '가입자',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 6),
                            Text(membership.church.name),
                            const SizedBox(height: 4),
                            Text(
                              _date(membership.requestedAt),
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 16),
                            OutlinedButton(
                              onPressed: () async {
                                await _showManagement(context, membership);
                                await _reload();
                              },
                              child: const Text('관리'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _date(DateTime date) =>
      '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';

  Future<void> _showManagement(
    BuildContext context,
    ChurchMembership membership,
  ) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _MembershipManagementSheet(membership: membership),
  );
}

class _MembershipManagementSheet extends StatefulWidget {
  const _MembershipManagementSheet({required this.membership});
  final ChurchMembership membership;
  @override
  State<_MembershipManagementSheet> createState() =>
      _MembershipManagementSheetState();
}

class _MembershipManagementSheetState
    extends State<_MembershipManagementSheet> {
  AppRole? _role;
  final Set<AppPermission> _added = {};
  final Set<AppPermission> _excluded = {};
  bool _submitting = false;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final roles = state.roles;
    _role ??= roles.firstOrNull;
    final effective = EffectivePermission.calculate(
      rolePermissions: _role?.defaultPermissions ?? const {},
      addedPermissions: _added,
      excludedPermissions: _excluded,
    ).toList()..sort((a, b) => a.code.compareTo(b.code));
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          14,
          20,
          MediaQuery.viewInsetsOf(context).bottom + 24,
        ),
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.88,
          minChildSize: 0.6,
          maxChildSize: 0.95,
          builder: (context, controller) => ListView(
            controller: controller,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD7DDDA),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                '${widget.membership.church.name} 가입 관리',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 22),
              DropdownButtonFormField<AppRole>(
                initialValue: _role,
                decoration: const InputDecoration(labelText: 'Role'),
                items: [
                  for (final role in roles)
                    DropdownMenuItem(value: role, child: Text(role.name)),
                ],
                onChanged: (role) => setState(() {
                  _role = role;
                  _added.clear();
                  _excluded.clear();
                }),
              ),
              const SizedBox(height: 20),
              _PermissionCodes(
                title: 'Role 기본 Permission',
                permissions: _role?.defaultPermissions ?? const {},
              ),
              const SizedBox(height: 12),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: const Text(
                  '사용자 추가 Permission',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text('${_added.length}개 선택'),
                children: [
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      for (final permission in AppPermission.values)
                        FilterChip(
                          label: Text(
                            permission.code,
                            style: const TextStyle(fontSize: 11),
                          ),
                          selected: _added.contains(permission),
                          onSelected: (selected) => setState(() {
                            if (selected) {
                              _added.add(permission);
                              _excluded.remove(permission);
                            } else {
                              _added.remove(permission);
                            }
                          }),
                        ),
                    ],
                  ),
                ],
              ),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: const Text(
                  '사용자 제외 Permission',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text('${_excluded.length}개 선택'),
                children: [
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      for (final permission in AppPermission.values)
                        FilterChip(
                          label: Text(
                            permission.code,
                            style: const TextStyle(fontSize: 11),
                          ),
                          selected: _excluded.contains(permission),
                          onSelected: (selected) => setState(() {
                            if (selected) {
                              _excluded.add(permission);
                              _added.remove(permission);
                            } else {
                              _excluded.remove(permission);
                            }
                          }),
                        ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _PermissionCodes(
                title: '최종 Effective Permission',
                permissions: effective.toSet(),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _submitting || _role == null
                    ? null
                    : () async {
                        setState(() => _submitting = true);
                        await state.approveMembership(
                          membership: widget.membership,
                          role: _role!,
                          addedPermissions: _added,
                          excludedPermissions: _excluded,
                        );
                        if (context.mounted) Navigator.of(context).pop();
                      },
                child: const Text('승인'),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: _submitting
                    ? null
                    : () async {
                        setState(() => _submitting = true);
                        await state.rejectMembership(widget.membership);
                        if (context.mounted) Navigator.of(context).pop();
                      },
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.redAccent,
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text('거절'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PermissionCodes extends StatelessWidget {
  const _PermissionCodes({required this.title, required this.permissions});
  final String title;
  final Set<AppPermission> permissions;
  @override
  Widget build(BuildContext context) {
    final sorted = permissions.toList()
      ..sort((a, b) => a.code.compareTo(b.code));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        if (sorted.isEmpty)
          const Text('없음', style: TextStyle(color: AppTheme.muted))
        else
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final permission in sorted)
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
      ],
    );
  }
}
