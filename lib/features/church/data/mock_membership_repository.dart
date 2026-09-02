import '../../../core/mock/mock_app_data_store.dart';
import '../../../core/permission/app_permission.dart';
import '../../../core/permission/app_role.dart';
import '../../../core/permission/effective_permission.dart';
import '../../../shared/models/church.dart';
import '../../../shared/models/user.dart';
import 'membership_repository.dart';

class MockMembershipRepository implements MembershipRepository {
  MockMembershipRepository(this.store);
  final MockAppDataStore store;

  @override
  Future<ChurchMembership> requestJoin({
    required String userId,
    required String churchId,
  }) async {
    final user = store.userById(userId);
    if (user == null) throw const MembershipException('사용자를 찾을 수 없습니다.');
    final existingIndex = user.memberships.indexWhere(
      (membership) => membership.church.id == churchId,
    );
    if (existingIndex >= 0 &&
        user.memberships[existingIndex].status != MembershipStatus.rejected) {
      throw const MembershipException('이미 가입했거나 가입 신청 중인 교회입니다.');
    }
    Church? church;
    for (final item in store.churches) {
      if (item.id == churchId) church = item;
    }
    if (church == null) throw const MembershipException('교회를 찾을 수 없습니다.');
    final membership = ChurchMembership(
      id: existingIndex < 0
          ? 'membership-${DateTime.now().microsecondsSinceEpoch}'
          : user.memberships[existingIndex].id,
      userId: userId,
      church: church,
      status: MembershipStatus.pending,
      requestedAt: DateTime.now(),
    );
    final memberships = [...user.memberships];
    if (existingIndex < 0) {
      memberships.add(membership);
    } else {
      memberships[existingIndex] = membership;
    }
    store.replaceUser(user.copyWith(memberships: memberships));
    return membership;
  }

  @override
  Future<List<ChurchMembership>> getPendingMemberships({
    required String churchId,
  }) async => [
    for (final user in store.users)
      ...user.memberships.where(
        (membership) =>
            membership.status == MembershipStatus.pending &&
            membership.church.id == churchId,
      ),
  ];

  @override
  Future<MembershipPermissionBreakdown> getPermissions(
    String membershipId,
  ) async {
    final membership = _find(membershipId);
    return MembershipPermissionBreakdown(
      rolePermissions: membership.role?.defaultPermissions ?? const {},
      grantedPermissions: membership.addedPermissions,
      deniedPermissions: membership.excludedPermissions,
      effectivePermissions: membership.effectivePermissions,
    );
  }

  @override
  Future<ChurchMembership> approve({
    required String churchId,
    required String membershipId,
    required AppRole role,
    Set<AppPermission> addedPermissions = const {},
    Set<AppPermission> excludedPermissions = const {},
  }) async => _replace(
    membershipId,
    (membership) => membership.copyWith(
      status: MembershipStatus.approved,
      role: role,
      addedPermissions: Set.unmodifiable(addedPermissions),
      excludedPermissions: Set.unmodifiable(excludedPermissions),
      approvedAt: DateTime.now(),
    ),
  );

  @override
  Future<ChurchMembership> reject({
    required String churchId,
    required String membershipId,
  }) async => _replace(
    membershipId,
    (membership) => membership.copyWith(status: MembershipStatus.rejected),
  );

  @override
  Future<ChurchMembership> updatePermissions({
    required String churchId,
    required String membershipId,
    required AppRole role,
    Set<AppPermission> addedPermissions = const {},
    Set<AppPermission> excludedPermissions = const {},
  }) async => _replace(
    membershipId,
    (membership) => membership.copyWith(
      role: role,
      addedPermissions: addedPermissions,
      excludedPermissions: excludedPermissions,
      resolvedPermissions: EffectivePermission.calculate(
        rolePermissions: role.defaultPermissions,
        addedPermissions: addedPermissions,
        excludedPermissions: excludedPermissions,
      ),
    ),
  );

  ChurchMembership _find(String membershipId) {
    for (final user in store.users) {
      for (final membership in user.memberships) {
        if (membership.id == membershipId) return membership;
      }
    }
    throw const MembershipException('가입 정보를 찾을 수 없습니다.');
  }

  ChurchMembership _replace(
    String membershipId,
    ChurchMembership Function(ChurchMembership) update,
  ) {
    for (final user in store.users) {
      final index = user.memberships.indexWhere(
        (membership) => membership.id == membershipId,
      );
      if (index < 0) continue;
      final current = user.memberships[index];
      if (current.status != MembershipStatus.pending)
        throw const MembershipException('이미 처리된 가입 신청입니다.');
      final updated = update(current);
      final memberships = [...user.memberships]..[index] = updated;
      store.replaceUser(user.copyWith(memberships: memberships));
      return updated;
    }
    throw const MembershipException('가입 신청을 찾을 수 없습니다.');
  }
}
