import '../../../core/network/api_client.dart';
import '../../../core/network/api_model_mapper.dart';
import '../domain/video_models.dart';
import 'video_repository.dart';

class ApiVideoRepository implements VideoRepository {
  ApiVideoRepository(this.client);
  final ApiClient client;
  @override
  Future<List<VideoItem>> listVideos(
    String churchId, {
    VideoFilters filters = const VideoFilters(),
  }) => _list(_path('/api/v1/churches/$churchId/videos', filters), _video);
  @override
  Future<VideoItem> getVideo(String churchId, String videoId) =>
      _one('/api/v1/churches/$churchId/videos/$videoId', _video);
  @override
  Future<List<VideoArchive>> getArchive(String churchId) =>
      _list('/api/v1/churches/$churchId/videos/archive', _archive);
  @override
  Future<List<VideoCategory>> listCategories(String churchId) =>
      _list('/api/v1/churches/$churchId/video-categories', _category);
  @override
  Future<List<VideoCollection>> listCollections(String churchId) =>
      _list('/api/v1/churches/$churchId/video-collections', _collection);
  @override
  Future<VideoCollection> getCollection(String churchId, String collectionId) =>
      _one(
        '/api/v1/churches/$churchId/video-collections/$collectionId',
        _collection,
      );
  @override
  Future<VideoItem> registerYouTube(
    String churchId,
    Map<String, dynamic> request,
  ) async {
    try {
      return _video(
        await client.post(
          '/api/v1/churches/$churchId/videos/youtube',
          body: request,
        ),
      );
    } on ApiException catch (e) {
      throw VideoDataException(e.message);
    }
  }

  @override
  Future<Map<String, dynamic>> testSynology(String churchId) async => _map(
    await client.post(
      '/api/v1/churches/$churchId/videos/synology/connection-test',
    ),
  );
  @override
  Future<Map<String, dynamic>> previewSynology(String churchId) async => _map(
    await client.post('/api/v1/churches/$churchId/videos/synology/preview'),
  );
  @override
  Future<Map<String, dynamic>> importSynology(
    String churchId,
    String token,
    List<String> refs,
  ) async => _map(
    await client.post(
      '/api/v1/churches/$churchId/videos/synology/import',
      body: {'snapshot_token': token, 'source_refs': refs},
    ),
  );

  Future<List<T>> _list<T>(String path, T Function(dynamic) map) async {
    try {
      final value = await client.get(path);
      if (value is! List)
        throw const VideoDataException('영상 응답 형식이 올바르지 않습니다.');
      return value.map(map).toList(growable: false);
    } on ApiException catch (e) {
      throw VideoDataException(e.message);
    }
  }

  Future<T> _one<T>(String path, T Function(dynamic) map) async {
    try {
      return map(await client.get(path));
    } on ApiException catch (e) {
      throw VideoDataException(e.message);
    }
  }

  static String _path(String base, VideoFilters f) {
    final q = <String>[];
    if (f.year != null) q.add('year=${f.year}');
    if (f.month != null) q.add('month=${f.month}');
    if (f.categoryId != null)
      q.add('category_id=${Uri.encodeQueryComponent(f.categoryId!)}');
    if (f.collectionId != null)
      q.add('collection_id=${Uri.encodeQueryComponent(f.collectionId!)}');
    return q.isEmpty ? base : '$base?${q.join('&')}';
  }

  static Map<String, dynamic> _map(dynamic value) =>
      ApiModelMapper.asMap(value);
  static String _string(Map<String, dynamic> m, String key) =>
      m[key] is String ? m[key] as String : '${m[key] ?? ''}';
  static DateTime _date(dynamic value) =>
      DateTime.tryParse(value?.toString() ?? '')?.toLocal() ??
      DateTime.fromMillisecondsSinceEpoch(0);
  static VideoItem _video(dynamic json) {
    final m = _map(json);
    return VideoItem(
      id: _string(m, 'id'),
      churchId: _string(m, 'church_id'),
      title: _string(m, 'title'),
      description: m['description'] as String?,
      sourceType: switch (m['source_type']) {
        'synology' => VideoSourceType.synology,
        'youtube' => VideoSourceType.youtube,
        _ => VideoSourceType.unknown,
      },
      sourceRef: _string(m, 'source_ref'),
      recordedAt: _date(m['recorded_at']),
      durationSeconds: m['duration_seconds'] as int?,
      thumbnailRef: m['thumbnail_ref'] as String?,
      isPublished: m['is_published'] as bool? ?? false,
      categoryId: m['category_id'] == null ? null : '${m['category_id']}',
      collectionId: m['collection_id'] == null ? null : '${m['collection_id']}',
    );
  }

  static VideoCategory _category(dynamic json) {
    final m = _map(json);
    return VideoCategory(
      id: _string(m, 'id'),
      churchId: _string(m, 'church_id'),
      name: _string(m, 'name'),
      sortOrder: m['sort_order'] as int? ?? 0,
      isActive: m['is_active'] as bool? ?? false,
    );
  }

  static VideoCollection _collection(dynamic json) {
    final m = _map(json);
    return VideoCollection(
      id: _string(m, 'id'),
      churchId: _string(m, 'church_id'),
      categoryId: m['category_id'] == null ? null : '${m['category_id']}',
      title: _string(m, 'title'),
      description: m['description'] as String?,
      recordedAt: m['recorded_at'] == null ? null : _date(m['recorded_at']),
      sortOrder: m['sort_order'] as int? ?? 0,
      isPublished: m['is_published'] as bool? ?? false,
    );
  }

  static VideoArchive _archive(dynamic json) {
    final m = _map(json);
    return VideoArchive(
      year: m['year'] as int? ?? 0,
      month: m['month'] as int? ?? 0,
      videoCount: m['video_count'] as int? ?? 0,
    );
  }
}
