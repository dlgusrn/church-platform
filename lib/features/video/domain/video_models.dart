enum VideoSourceType { synology, youtube, unknown }

class VideoItem {
  const VideoItem({
    required this.id,
    required this.churchId,
    required this.title,
    this.description,
    required this.sourceType,
    required this.sourceRef,
    required this.recordedAt,
    this.durationSeconds,
    this.thumbnailRef,
    required this.isPublished,
    this.categoryId,
    this.collectionId,
  });
  final String id, churchId, title, sourceRef;
  final String? description, thumbnailRef, categoryId, collectionId;
  final VideoSourceType sourceType;
  final DateTime recordedAt;
  final int? durationSeconds;
  final bool isPublished;
}

class VideoPlaybackSession {
  const VideoPlaybackSession({
    required this.url,
    required this.token,
    required this.expiresAt,
  });
  final Uri url;
  final String token;
  final DateTime expiresAt;

  Map<String, String> get playbackHeaders => {'X-Playback-Token': token};
}

class VideoCategory {
  const VideoCategory({
    required this.id,
    required this.churchId,
    required this.name,
    required this.sortOrder,
    required this.isActive,
  });
  final String id, churchId, name;
  final int sortOrder;
  final bool isActive;
}

class VideoCollection {
  const VideoCollection({
    required this.id,
    required this.churchId,
    this.categoryId,
    required this.title,
    this.description,
    this.recordedAt,
    required this.sortOrder,
    required this.isPublished,
  });
  final String id, churchId, title;
  final String? categoryId, description;
  final DateTime? recordedAt;
  final int sortOrder;
  final bool isPublished;
}

class VideoArchive {
  const VideoArchive({
    required this.year,
    required this.month,
    required this.videoCount,
  });
  final int year, month, videoCount;
}

class VideoFilters {
  const VideoFilters({
    this.year,
    this.month,
    this.categoryId,
    this.collectionId,
  });
  final int? year, month;
  final String? categoryId, collectionId;
  VideoFilters copyWith({
    int? year,
    int? month,
    String? categoryId,
    String? collectionId,
    bool clearYear = false,
    bool clearMonth = false,
    bool clearCategory = false,
    bool clearCollection = false,
  }) => VideoFilters(
    year: clearYear ? null : year ?? this.year,
    month: clearMonth ? null : month ?? this.month,
    categoryId: clearCategory ? null : categoryId ?? this.categoryId,
    collectionId: clearCollection ? null : collectionId ?? this.collectionId,
  );
}
