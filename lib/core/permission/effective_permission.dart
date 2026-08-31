import 'app_permission.dart';

abstract final class EffectivePermission {
  static Set<AppPermission> calculate({
    required Set<AppPermission> rolePermissions,
    Set<AppPermission> addedPermissions = const {},
    Set<AppPermission> excludedPermissions = const {},
  }) {
    return {...rolePermissions, ...addedPermissions}
      ..removeAll(excludedPermissions);
  }

  static bool hasAny(
    Set<AppPermission> effectivePermissions,
    Set<AppPermission> candidates,
  ) => candidates.any(effectivePermissions.contains);
}
