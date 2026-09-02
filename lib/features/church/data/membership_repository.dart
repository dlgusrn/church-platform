import '../../../core/permission/app_permission.dart';
import '../../../core/permission/app_role.dart';
import '../../../shared/models/user.dart';

abstract interface class MembershipRepository {
  Future<ChurchMembership> requestJoin({
    required String userId,
    required String churchId,
  });
  Future<List<ChurchMembership>> getPendingMemberships({
    required String churchId,
  });
  Future<MembershipPermissionBreakdown> getPermissions(String membershipId);
  Future<ChurchMembership> approve({
    required String churchId,
    required String membershipId,
    required AppRole role,
    Set<AppPermission> addedPermissions,
    Set<AppPermission> excludedPermissions,
  });
  Future<ChurchMembership> reject({
    required String churchId,
    required String membershipId,
  });
  Future<ChurchMembership> updatePermissions({
    required String churchId,
    required String membershipId,
    required AppRole role,
    Set<AppPermission> addedPermissions,
    Set<AppPermission> excludedPermissions,
  });
}

class MembershipPermissionBreakdown {
  const MembershipPermissionBreakdown({
    required this.rolePermissions,
    required this.grantedPermissions,
    required this.deniedPermissions,
    required this.effectivePermissions,
  });
  final Set<AppPermission> rolePermissions;
  final Set<AppPermission> grantedPermissions;
  final Set<AppPermission> deniedPermissions;
  final Set<AppPermission> effectivePermissions;
}

class MembershipException implements Exception {
  const MembershipException(this.message);
  final String message;
}
