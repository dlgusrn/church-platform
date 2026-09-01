import 'app_permission.dart';

class AppRole {
  const AppRole({
    required this.id,
    required this.name,
    required this.defaultPermissions,
  });

  final String id;
  final String name;
  final Set<AppPermission> defaultPermissions;
}
