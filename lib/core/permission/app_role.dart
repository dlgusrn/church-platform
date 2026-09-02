import 'app_permission.dart';

class AppRole {
  const AppRole({
    required this.id,
    required this.name,
    required this.defaultPermissions,
    this.code = '',
    this.isSystem = false,
  });

  final String id;
  final String name;
  final String code;
  final bool isSystem;
  final Set<AppPermission> defaultPermissions;
}
