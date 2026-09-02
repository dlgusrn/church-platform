class Notice {
  const Notice({
    required this.id,
    required this.churchId,
    required this.title,
    required this.content,
    required this.isPinned,
    required this.publishedAt,
    required this.createdAt,
    required this.updatedAt,
  });
  final String id;
  final String churchId;
  final String title;
  final String content;
  final bool isPinned;
  final DateTime publishedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  String get listDate =>
      '${publishedAt.year.toString().padLeft(4, '0')}.${publishedAt.month.toString().padLeft(2, '0')}.${publishedAt.day.toString().padLeft(2, '0')}';
  String get detailDate =>
      '${publishedAt.year}년 ${publishedAt.month}월 ${publishedAt.day}일';
}

class NoticeDraft {
  const NoticeDraft({
    required this.title,
    required this.content,
    required this.isPinned,
  });
  final String title;
  final String content;
  final bool isPinned;
}
