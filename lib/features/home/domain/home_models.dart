enum LiveBroadcastStatus { scheduled, live, ended }

enum LiveWorshipType { day, night, prayer11, special, custom }

extension LiveWorshipTypeLabel on LiveWorshipType {
  String get label => switch (this) {
    LiveWorshipType.day => '낮예배',
    LiveWorshipType.night => '밤예배',
    LiveWorshipType.prayer11 => '11시기도',
    LiveWorshipType.special => '특별성회',
    LiveWorshipType.custom => '직접 입력',
  };

  String get apiValue => switch (this) {
    LiveWorshipType.prayer11 => 'prayer_11',
    _ => name,
  };
}

class WorshipSchedule {
  const WorshipSchedule({
    required this.id,
    required this.churchId,
    required this.title,
    required this.dayLabel,
    required this.time,
    required this.displayOrder,
    required this.isActive,
  });

  final String id;
  final String churchId;
  final String title;
  final String dayLabel;
  final String time;
  final int displayOrder;
  final bool isActive;

  String get name => title;
  String get displayTime => time.length >= 5 ? time.substring(0, 5) : time;
}

class WorshipScheduleDraft {
  const WorshipScheduleDraft({
    required this.title,
    required this.dayLabel,
    required this.time,
    required this.displayOrder,
    required this.isActive,
  });

  final String title;
  final String dayLabel;
  final String time;
  final int displayOrder;
  final bool isActive;
}

class LiveBroadcast {
  const LiveBroadcast({
    required this.id,
    required this.churchId,
    required this.displayTitle,
    required this.youtubeUrl,
    required this.status,
    required this.broadcastDate,
    required this.worshipType,
    this.customWorshipName,
    this.titleOverride,
    this.startedAt,
    this.endedAt,
  });

  final String id;
  final String churchId;
  final LiveWorshipType worshipType;
  final String? customWorshipName;
  final DateTime broadcastDate;
  final String? titleOverride;
  final String displayTitle;
  final String youtubeUrl;
  final LiveBroadcastStatus status;
  final DateTime? startedAt;
  final DateTime? endedAt;

  String get title => displayTitle;
  bool get isLive => status == LiveBroadcastStatus.live;
  bool get isScheduled => status == LiveBroadcastStatus.scheduled;
  String get worshipLabel => customWorshipName ?? worshipType.label;
}

class LiveBroadcastDraft {
  const LiveBroadcastDraft({
    required this.broadcastDate,
    required this.youtubeUrl,
    required this.status,
    required this.worshipType,
    this.customWorshipName,
    this.titleOverride,
  });

  final LiveWorshipType worshipType;
  final String? customWorshipName;
  final DateTime broadcastDate;
  final String? titleOverride;
  final String youtubeUrl;
  final LiveBroadcastStatus status;
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

  List<WorshipSchedule> get orderedSchedules {
    final result = [...schedules];
    result.sort((a, b) {
      var comparison = a.displayOrder.compareTo(b.displayOrder);
      if (comparison != 0) return comparison;
      comparison = a.time.compareTo(b.time);
      return comparison != 0 ? comparison : a.id.compareTo(b.id);
    });
    return result;
  }
}
