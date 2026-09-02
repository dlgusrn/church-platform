import '../domain/home_models.dart';
import 'home_repository.dart';

class MockHomeRepository implements HomeRepository {
  final Map<String, List<WorshipSchedule>> _schedules = {};
  final Map<String, List<LiveBroadcast>> _broadcasts = {};

  List<WorshipSchedule> _churchSchedules(String churchId) =>
      _schedules.putIfAbsent(churchId, () => [_fixtureSchedule(churchId)]);

  List<LiveBroadcast> _churchBroadcasts(String churchId) =>
      _broadcasts.putIfAbsent(
        churchId,
        () => [
          LiveBroadcast(
            id: 'live-$churchId',
            churchId: churchId,
            worshipType: LiveWorshipType.special,
            broadcastDate: DateTime.now(),
            displayTitle: '개발 테스트 생방송',
            youtubeUrl: 'https://youtu.be/mock-youtube-id',
            status: LiveBroadcastStatus.live,
          ),
        ],
      );

  @override
  Future<HomeContent> getHomeContent(
    String churchId, {
    bool includeSchedules = true,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 80));
    final current = _churchBroadcasts(churchId)
        .where((item) => item.status == LiveBroadcastStatus.live)
        .firstOrNull;
    return HomeContent(
      live: current,
      schedules: includeSchedules
          ? _churchSchedules(churchId).where((item) => item.isActive).toList()
          : const [],
      recentVideos: const [],
    );
  }

  @override
  Future<List<WorshipSchedule>> getWorshipSchedules(
    String churchId, {
    bool includeInactive = false,
  }) async =>
      _churchSchedules(churchId)
          .where((item) => includeInactive || item.isActive)
          .toList(growable: false);

  @override
  Future<WorshipSchedule> createWorshipSchedule(
    String churchId,
    WorshipScheduleDraft draft,
  ) async {
    final item = _fromDraft(
      id: 'schedule-${_churchSchedules(churchId).length + 1}',
      churchId: churchId,
      draft: draft,
    );
    _churchSchedules(churchId).add(item);
    return item;
  }

  @override
  Future<WorshipSchedule> updateWorshipSchedule(
    String churchId,
    String scheduleId,
    WorshipScheduleDraft draft,
  ) async {
    final items = _churchSchedules(churchId);
    final index = items.indexWhere((item) => item.id == scheduleId);
    final updated = _fromDraft(
      id: scheduleId,
      churchId: churchId,
      draft: draft,
    );
    items[index] = updated;
    return updated;
  }

  @override
  Future<List<LiveBroadcast>> getLiveBroadcasts(String churchId) async =>
      List.unmodifiable(_churchBroadcasts(churchId));

  @override
  Future<LiveBroadcast> createLiveBroadcast(
    String churchId,
    LiveBroadcastDraft draft,
  ) async {
    final item = _liveFromDraft(
      id: 'live-${_churchBroadcasts(churchId).length + 1}',
      churchId: churchId,
      draft: draft,
    );
    _churchBroadcasts(churchId).add(item);
    return item;
  }

  @override
  Future<LiveBroadcast> updateLiveBroadcast(
    String churchId,
    String broadcastId,
    LiveBroadcastDraft draft,
  ) async {
    final items = _churchBroadcasts(churchId);
    final index = items.indexWhere((item) => item.id == broadcastId);
    final updated = _liveFromDraft(
      id: broadcastId,
      churchId: churchId,
      draft: draft,
    );
    items[index] = updated;
    return updated;
  }

  WorshipSchedule _fixtureSchedule(String churchId) => WorshipSchedule(
    id: 'schedule-$churchId',
    churchId: churchId,
    title: '개발 테스트 예배',
    dayLabel: '개발용',
    time: '19:00:00',
    displayOrder: 0,
    isActive: true,
  );

  static WorshipSchedule _fromDraft({
    required String id,
    required String churchId,
    required WorshipScheduleDraft draft,
  }) => WorshipSchedule(
    id: id,
    churchId: churchId,
    title: draft.title,
    dayLabel: draft.dayLabel,
    time: draft.time,
    displayOrder: draft.displayOrder,
    isActive: draft.isActive,
  );

  LiveBroadcast _liveFromDraft({
    required String id,
    required String churchId,
    required LiveBroadcastDraft draft,
  }) {
    final title = draft.titleOverride?.trim().isNotEmpty == true
        ? draft.titleOverride!.trim()
        : '${draft.customWorshipName ?? draft.worshipType.label} 생방송';
    return LiveBroadcast(
      id: id,
      churchId: churchId,
      worshipType: draft.worshipType,
      customWorshipName: draft.customWorshipName,
      broadcastDate: draft.broadcastDate,
      titleOverride: draft.titleOverride,
      displayTitle: title,
      youtubeUrl: draft.youtubeUrl,
      status: draft.status,
    );
  }
}
