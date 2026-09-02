import 'app_role.dart';

abstract interface class RoleRepository {
  Future<List<AppRole>> getRoles(String churchId);
}
