class LiveBroadcast {
  const LiveBroadcast({
    required this.id,
    required this.churchId,
    required this.title,
    required this.thumbnailUrl,
    required this.startedAt,
    required this.youtubeVideoId,
    required this.isLive,
  });
  final String id;
  final String churchId;
  final String title;
  final String thumbnailUrl;
  final DateTime startedAt;
  final String youtubeVideoId;
  final bool isLive;
}

class WorshipSchedule {
  const WorshipSchedule({required this.name, required this.time});
  final String name;
  final String time;
}

class RecentVideo {
  const RecentVideo({
    required this.id,
    required this.churchId,
    required this.title,
    required this.publishedAt,
    required this.duration,
    required this.thumbnailUrl,
  });
  final String id;
  final String churchId;
  final String title;
  final DateTime publishedAt;
  final String duration;
  final String thumbnailUrl;
}

class HomeContent {
  const HomeContent({
    required this.live,
    required this.schedules,
    required this.recentVideos,
  });
  final LiveBroadcast? live;
  final List<WorshipSchedule> schedules;
  final List<RecentVideo> recentVideos;
}
