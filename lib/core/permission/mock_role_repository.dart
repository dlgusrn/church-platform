import '../mock/mock_app_data_store.dart';
import 'app_role.dart';
import 'role_repository.dart';

class MockRoleRepository implements RoleRepository {
  MockRoleRepository(this.store);
  final MockAppDataStore store;
  @override
  Future<List<AppRole>> getRoles(String churchId) async =>
      List.unmodifiable(store.roles);
}
