import '../domain/notice_models.dart';

abstract interface class NoticeRepository {
  Future<List<Notice>> listNotices(String churchId);
  Future<Notice> getNotice(String churchId, String noticeId);
  Future<Notice> createNotice(String churchId, NoticeDraft draft);
  Future<Notice> updateNotice(
    String churchId,
    String noticeId,
    NoticeDraft draft,
  );
  Future<void> deleteNotice(String churchId, String noticeId);
}

class NoticeDataException implements Exception {
  const NoticeDataException(this.message);
  final String message;
  @override
  String toString() => message;
}
