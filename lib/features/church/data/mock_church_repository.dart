import '../../../core/mock/mock_app_data_store.dart';
import '../../../shared/models/church.dart';
import 'church_repository.dart';

class MockChurchRepository implements ChurchRepository {
  MockChurchRepository(this.store);
  final MockAppDataStore store;
  @override
  Future<List<Church>> getChurches() async => List.unmodifiable(store.churches);
}
