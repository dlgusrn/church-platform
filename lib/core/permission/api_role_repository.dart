import '../network/api_client.dart';
import '../network/api_model_mapper.dart';
import 'app_role.dart';
import 'role_repository.dart';

class ApiRoleRepository implements RoleRepository {
  ApiRoleRepository(this.client);
  final ApiClient client;

  @override
  Future<List<AppRole>> getRoles(String churchId) async =>
      (await client.get('/api/v1/churches/$churchId/roles') as List)
          .map(ApiModelMapper.role)
          .toList(growable: false);
}
