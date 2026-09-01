import '../../../shared/models/church.dart';

abstract interface class ChurchRepository {
  Future<List<Church>> getChurches();
}
