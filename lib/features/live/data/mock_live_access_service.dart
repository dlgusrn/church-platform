import 'live_access_service.dart';

class MockLiveAccessService implements LiveAccessService {
  static const demoPassword = '123456';
  @override
  LiveAccessGrant grantByPermission(String liveId) =>
      LiveAccessGrant(liveId: liveId, grantedAt: DateTime.now());
  @override
  Future<LiveAccessGrant?> verifyPassword({
    required String liveId,
    required String password,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 450));
    if (password != demoPassword) return null;
    return LiveAccessGrant(liveId: liveId, grantedAt: DateTime.now());
  }
}
