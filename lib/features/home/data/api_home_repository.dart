import '../../../core/network/api_client.dart';
import '../../../core/network/api_model_mapper.dart';
import '../domain/home_models.dart';
import 'home_repository.dart';

class ApiHomeRepository implements HomeRepository {
  ApiHomeRepository(this.client);
  final ApiClient client;

  @override
  Future<HomeContent> getHomeContent(
    String churchId, {
    bool includeSchedules = true,
  }) async {
    try {
      final schedules = includeSchedules
          ? await getWorshipSchedules(churchId)
          : const <WorshipSchedule>[];
      final liveJson = await client.get(
        '/api/v1/churches/$churchId/live-broadcasts/current',
      );
      return HomeContent(
        live: liveJson == null ? null : _live(liveJson),
        schedules: schedules,
        recentVideos: const [],
      );
    } on ApiException catch (error) {
      throw HomeDataException(error.message);
    }
  }

  @override
  Future<List<WorshipSchedule>> getWorshipSchedules(
    String churchId, {
    bool includeInactive = false,
  }) async => _requestList(
    '/api/v1/churches/$churchId/worship-schedules'
    '${includeInactive ? '?include_inactive=true' : ''}',
    _schedule,
  );

  @override
  Future<WorshipSchedule> createWorshipSchedule(
    String churchId,
    WorshipScheduleDraft draft,
  ) => _requestOne(
    () => client.post(
      '/api/v1/churches/$churchId/worship-schedules',
      body: _scheduleBody(draft),
    ),
    _schedule,
  );

  @override
  Future<WorshipSchedule> updateWorshipSchedule(
    String churchId,
    String scheduleId,
    WorshipScheduleDraft draft,
  ) => _requestOne(
    () => client.patch(
      '/api/v1/churches/$churchId/worship-schedules/$scheduleId',
      body: _scheduleBody(draft),
    ),
    _schedule,
  );

  @override
  Future<List<LiveBroadcast>> getLiveBroadcasts(String churchId) =>
      _requestList('/api/v1/churches/$churchId/live-broadcasts', _live);

  @override
  Future<LiveBroadcast> createLiveBroadcast(
    String churchId,
    LiveBroadcastDraft draft,
  ) => _requestOne(
    () => client.post(
      '/api/v1/churches/$churchId/live-broadcasts',
      body: _liveBody(draft),
    ),
    _live,
  );

  @override
  Future<LiveBroadcast> updateLiveBroadcast(
    String churchId,
    String broadcastId,
    LiveBroadcastDraft draft,
  ) => _requestOne(
    () => client.patch(
      '/api/v1/churches/$churchId/live-broadcasts/$broadcastId',
      body: _liveBody(draft),
    ),
    _live,
  );

  Future<List<T>> _requestList<T>(
    String path,
    T Function(dynamic) mapper,
  ) async {
    try {
      return (await client.get(path) as List)
          .map(mapper)
          .toList(growable: false);
    } on ApiException catch (error) {
      throw HomeDataException(error.message);
    }
  }

  Future<T> _requestOne<T>(
    Future<dynamic> Function() request,
    T Function(dynamic) mapper,
  ) async {
    try {
      return mapper(await request());
    } on ApiException catch (error) {
      throw HomeDataException(error.message);
    }
  }

  static WorshipSchedule _schedule(dynamic json) {
    final map = ApiModelMapper.asMap(json);
    return WorshipSchedule(
      id: '${map['id']}',
      churchId: '${map['church_id']}',
      title: map['title'] as String,
      dayLabel: map['day_label'] as String,
      time: map['time'] as String,
      displayOrder: map['display_order'] as int,
      isActive: map['is_active'] as bool,
    );
  }

  static LiveBroadcast _live(dynamic json) {
    final map = ApiModelMapper.asMap(json);
    return LiveBroadcast(
      id: '${map['id']}',
      churchId: '${map['church_id']}',
      worshipType: _worshipType(map['worship_type']),
      customWorshipName: map['custom_worship_name'] as String?,
      broadcastDate: DateTime.parse(map['broadcast_date'] as String),
      titleOverride: map['title_override'] as String?,
      displayTitle: map['display_title'] as String,
      youtubeUrl: map['youtube_url'] as String,
      status: _status(map['status']),
      startedAt: map['started_at'] == null
          ? null
          : DateTime.parse(map['started_at'] as String),
      endedAt: map['ended_at'] == null
          ? null
          : DateTime.parse(map['ended_at'] as String),
    );
  }

  static LiveBroadcastStatus _status(dynamic value) => switch (value) {
    'scheduled' => LiveBroadcastStatus.scheduled,
    'live' => LiveBroadcastStatus.live,
    'ended' => LiveBroadcastStatus.ended,
    _ => throw const HomeDataException('알 수 없는 LIVE 상태입니다.'),
  };

  static LiveWorshipType _worshipType(dynamic value) => switch (value) {
    'day' => LiveWorshipType.day,
    'night' => LiveWorshipType.night,
    'prayer_11' => LiveWorshipType.prayer11,
    'special' => LiveWorshipType.special,
    'custom' => LiveWorshipType.custom,
    _ => throw const HomeDataException('알 수 없는 LIVE 예배 유형입니다.'),
  };

  static Map<String, dynamic> _scheduleBody(WorshipScheduleDraft draft) => {
    'title': draft.title,
    'day_label': draft.dayLabel,
    'time': draft.time,
    'display_order': draft.displayOrder,
    'is_active': draft.isActive,
  };

  static Map<String, dynamic> _liveBody(LiveBroadcastDraft draft) => {
    'worship_type': draft.worshipType.apiValue,
    'custom_worship_name': draft.customWorshipName,
    'broadcast_date': _date(draft.broadcastDate),
    'title_override': draft.titleOverride,
    'youtube_url': draft.youtubeUrl,
    'status': draft.status.name,
  };

  static String _date(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}
