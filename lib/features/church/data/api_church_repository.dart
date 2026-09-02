import '../../../core/network/api_client.dart';
import '../../../core/network/api_model_mapper.dart';
import '../../../shared/models/church.dart';
import 'church_repository.dart';

class ApiChurchRepository implements ChurchRepository {
  ApiChurchRepository(this.client);
  final ApiClient client;

  @override
  Future<List<Church>> getChurches() async =>
      (await client.get('/api/v1/churches') as List)
          .map(ApiModelMapper.church)
          .toList(growable: false);
}
