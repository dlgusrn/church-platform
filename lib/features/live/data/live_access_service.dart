class LiveAccessGrant {
  const LiveAccessGrant({required this.liveId, required this.grantedAt});
  final String liveId;
  final DateTime grantedAt;
}

abstract interface class LiveAccessService {
  Future<LiveAccessGrant?> verifyPassword({
    required String liveId,
    required String password,
  });
  LiveAccessGrant grantByPermission(String liveId);
}
