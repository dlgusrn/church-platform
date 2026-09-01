import '../../../core/permission/app_permission.dart';
import '../../../core/permission/app_role.dart';
import '../../../shared/models/user.dart';

abstract interface class MembershipRepository {
  Future<ChurchMembership> requestJoin({
    required String userId,
    required String churchId,
  });
  Future<List<ChurchMembership>> getPendingMemberships();
  Future<ChurchMembership> approve({
    required String membershipId,
    required AppRole role,
    Set<AppPermission> addedPermissions,
    Set<AppPermission> excludedPermissions,
  });
  Future<ChurchMembership> reject(String membershipId);
}

class MembershipException implements Exception {
  const MembershipException(this.message);
  final String message;
}
