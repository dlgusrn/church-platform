import '../domain/video_models.dart';

abstract interface class VideoRepository {
  Future<List<VideoItem>> listVideos(
    String churchId, {
    VideoFilters filters = const VideoFilters(),
  });
  Future<VideoItem> getVideo(String churchId, String videoId);
  Future<VideoItem> updateVideo(
    String churchId,
    String videoId,
    Map<String, dynamic> request,
  );
  Future<VideoPlaybackSession> createPlaybackSession(
    String churchId,
    String videoId,
  );
  Future<List<VideoArchive>> getArchive(String churchId);
  Future<List<VideoCategory>> listCategories(String churchId);
  Future<List<VideoCollection>> listCollections(String churchId);
  Future<VideoCollection> getCollection(String churchId, String collectionId);
  Future<VideoItem> registerYouTube(
    String churchId,
    Map<String, dynamic> request,
  );
  Future<Map<String, dynamic>> testSynology(String churchId);
  Future<Map<String, dynamic>> previewSynology(
    String churchId, {
    String? snapshotToken,
    int offset = 0,
    int limit = 100,
    String status = 'all',
    String? folder,
  });
  Future<Map<String, dynamic>> importSynology(
    String churchId,
    String token,
    List<String> refs,
  );
  Future<Map<String, dynamic>> reviewVideos(
    String churchId, {
    String status = 'unpublished',
    int offset = 0,
    int limit = 100,
  });
  Future<Map<String, dynamic>> bulkPublish(
    String churchId,
    List<String> videoIds,
  );
}

class VideoDataException implements Exception {
  const VideoDataException(this.message);
  final String message;
  @override
  String toString() => message;
}

class SynologySnapshotExpiredException extends VideoDataException {
  const SynologySnapshotExpiredException() : super('NAS 목록을 다시 불러와 주세요.');
}

class SynologyCandidateInvalidException extends VideoDataException {
  const SynologyCandidateInvalidException() : super('선택한 영상 정보를 다시 불러와 주세요.');
}

class SynologyPermissionException extends VideoDataException {
  const SynologyPermissionException() : super('영상 관리 권한이 없습니다.');
}
