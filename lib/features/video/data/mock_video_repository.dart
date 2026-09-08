import '../domain/video_models.dart';
import 'video_repository.dart';

class MockVideoRepository implements VideoRepository {
  @override
  Future<Map<String, dynamic>> testSynology(String churchId) async => {
    'configured': false,
    'reachable': false,
    'authenticated': false,
    'root_accessible': false,
  };
  @override
  Future<Map<String, dynamic>> previewSynology(String churchId) async => {
    'snapshot_token': '',
    'summary': {'total': 0, 'new': 0, 'duplicate': 0, 'warning': 0},
    'candidates': [],
  };
  @override
  Future<Map<String, dynamic>> importSynology(
    String churchId,
    String token,
    List<String> refs,
  ) async => {'created': 0, 'skipped': 0, 'failed': 0};
  @override
  Future<VideoItem> registerYouTube(
    String churchId,
    Map<String, dynamic> request,
  ) => Future.error(const VideoDataException('등록할 수 없습니다.'));
  @override
  Future<VideoItem> getVideo(String churchId, String videoId) =>
      Future.error(const VideoDataException('등록된 영상을 찾을 수 없습니다.'));
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
