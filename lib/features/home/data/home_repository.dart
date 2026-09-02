import '../domain/home_models.dart';

abstract interface class HomeRepository {
  Future<HomeContent> getHomeContent(
    String churchId, {
    bool includeSchedules = true,
  });
  Future<List<WorshipSchedule>> getWorshipSchedules(
    String churchId, {
    bool includeInactive = false,
  });
  Future<WorshipSchedule> createWorshipSchedule(
    String churchId,
    WorshipScheduleDraft draft,
  );
  Future<WorshipSchedule> updateWorshipSchedule(
    String churchId,
    String scheduleId,
    WorshipScheduleDraft draft,
  );
  Future<List<LiveBroadcast>> getLiveBroadcasts(String churchId);
  Future<LiveBroadcast> createLiveBroadcast(
    String churchId,
    LiveBroadcastDraft draft,
  );
  Future<LiveBroadcast> updateLiveBroadcast(
    String churchId,
    String broadcastId,
    LiveBroadcastDraft draft,
  );
}

class HomeDataException implements Exception {
  const HomeDataException(this.message);
  final String message;

  @override
  String toString() => message;
}
