import '../../core/permission/app_permission.dart';
import '../../core/permission/effective_permission.dart';
import 'church.dart';

class ChurchMembership {
  const ChurchMembership({
    required this.church,
    required this.roleName,
    this.rolePermissions = const {},
    this.addedPermissions = const {},
    this.excludedPermissions = const {},
  });
  final Church church;
  final String roleName;
  final Set<AppPermission> rolePermissions;
  final Set<AppPermission> addedPermissions;
  final Set<AppPermission> excludedPermissions;
  Set<AppPermission> get effectivePermissions => EffectivePermission.calculate(
    rolePermissions: rolePermissions,
    addedPermissions: addedPermissions,
    excludedPermissions: excludedPermissions,
  );
}

class AppUser {
  const AppUser({
    required this.id,
    required this.name,
    required this.loginId,
    required this.memberships,
  });
  final String id;
  final String name;
  final String loginId;
  final List<ChurchMembership> memberships;
}
