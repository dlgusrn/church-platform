import '../domain/video_models.dart';

abstract interface class VideoRepository {
  Future<List<VideoItem>> listVideos(
    String churchId, {
    VideoFilters filters = const VideoFilters(),
  });
  Future<VideoItem> getVideo(String churchId, String videoId);
  Future<List<VideoArchive>> getArchive(String churchId);
  Future<List<VideoCategory>> listCategories(String churchId);
  Future<List<VideoCollection>> listCollections(String churchId);
  Future<VideoCollection> getCollection(String churchId, String collectionId);
  Future<VideoItem> registerYouTube(
    String churchId,
    Map<String, dynamic> request,
  );
  Future<Map<String, dynamic>> testSynology(String churchId);
  Future<Map<String, dynamic>> previewSynology(String churchId);
  Future<Map<String, dynamic>> importSynology(
    String churchId,
    String token,
    List<String> refs,
  );
}

class VideoDataException implements Exception {
  const VideoDataException(this.message);
  final String message;
  @override
  String toString() => message;
}
