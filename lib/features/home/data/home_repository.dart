import '../domain/home_models.dart';

abstract interface class HomeRepository {
  Future<HomeContent> getHomeContent(String churchId);
}
