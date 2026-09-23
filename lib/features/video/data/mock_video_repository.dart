import '../domain/video_models.dart';
import 'video_repository.dart';

class MockVideoRepository implements VideoRepository {
  @override
  Future<VideoPlaybackSession> createPlaybackSession(
    String churchId,
    String videoId,
  ) => Future.error(const VideoDataException('재생할 수 없습니다.'));
  @override
  Future<Map<String, dynamic>> testSynology(String churchId) async => {
    'configured': false,
    'reachable': false,
    'authenticated': false,
    'root_accessible': false,
  };
  @override
  Future<Map<String, dynamic>> previewSynology(
    String churchId, {
    String? snapshotToken,
    int offset = 0,
    int limit = 100,
    String status = 'all',
    String? folder,
  }) async => {
    'snapshot_token': '',
    'summary': {
      'total': 0,
      'filtered_total': 0,
      'new': 0,
      'already_imported': 0,
      'needs_review': 0,
      'ready': 0,
      'duplicate': 0,
      'warning': 0,
    },
    'candidates': [],
    'folder_facets': [],
    'offset': offset,
    'limit': limit,
  };
  @override
  Future<Map<String, dynamic>> importSynology(
    String churchId,
    String token,
    List<String> refs,
  ) async => {
    'requested_count': 0,
    'imported_count': 0,
    'already_imported_count': 0,
    'failed_count': 0,
    'needs_review_count': 0,
    'items': const [],
    'created': 0,
    'skipped': 0,
    'failed': 0,
  };
  @override
  Future<VideoItem> registerYouTube(
    String churchId,
    Map<String, dynamic> request,
  ) => Future.error(const VideoDataException('등록할 수 없습니다.'));
  @override
  Future<VideoItem> getVideo(String churchId, String videoId) =>
      Future.error(const VideoDataException('등록된 영상을 찾을 수 없습니다.'));
  @override
  Future<VideoItem> updateVideo(
    String churchId,
    String videoId,
    Map<String, dynamic> request,
  ) => Future.error(const VideoDataException('수정할 수 없습니다.'));
  @override
  Future<Map<String, dynamic>> reviewVideos(
    String churchId, {
    String status = 'unpublished',
    int offset = 0,
    int limit = 100,
  }) async => {
    'items': const [],
    'total': 0,
    'published_count': 0,
    'unpublished_count': 0,
    'offset': offset,
    'limit': limit,
  };
  @override
  Future<Map<String, dynamic>> bulkPublish(
    String churchId,
    List<String> videoIds,
  ) async => {
    'requested_count': videoIds.length,
    'published_count': 0,
    'already_published_count': 0,
    'failed_count': 0,
    'items': const [],
  };
  @override
  Future<List<VideoArchive>> getArchive(String churchId) async => const [];
  @override
  Future<VideoCollection> getCollection(String churchId, String collectionId) =>
      Future.error(const VideoDataException('등록된 모음을 찾을 수 없습니다.'));
  @override
  Future<List<VideoCategory>> listCategories(String churchId) async => const [];
  @override
  Future<List<VideoCollection>> listCollections(String churchId) async =>
      const [];
  @override
  Future<List<VideoItem>> listVideos(
    String churchId, {
    VideoFilters filters = const VideoFilters(),
  }) async => const [];
}
