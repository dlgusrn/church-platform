import '../domain/notice_models.dart';
import 'notice_repository.dart';

class MockNoticeRepository implements NoticeRepository {
  final Map<String, List<Notice>> _items = {};
  List<Notice> _forChurch(String churchId) =>
      _items.putIfAbsent(churchId, () => []);
  @override
  Future<List<Notice>> listNotices(String churchId) async =>
      List.unmodifiable(_forChurch(churchId));
  @override
  Future<Notice> getNotice(String churchId, String noticeId) async =>
      _forChurch(churchId).firstWhere((item) => item.id == noticeId);
  @override
  Future<Notice> createNotice(String churchId, NoticeDraft draft) async {
    final now = DateTime.now();
    final item = Notice(
      id: 'notice-${_forChurch(churchId).length + 1}',
      churchId: churchId,
      title: draft.title,
      content: draft.content,
      isPinned: draft.isPinned,
      publishedAt: now,
      createdAt: now,
      updatedAt: now,
    );
    _forChurch(churchId).insert(0, item);
    return item;
  }

  @override
  Future<Notice> updateNotice(
    String churchId,
    String noticeId,
    NoticeDraft draft,
  ) async {
    final items = _forChurch(churchId);
    final index = items.indexWhere((item) => item.id == noticeId);
    final old = items[index];
    final item = Notice(
      id: old.id,
      churchId: old.churchId,
      title: draft.title,
      content: draft.content,
      isPinned: draft.isPinned,
      publishedAt: old.publishedAt,
      createdAt: old.createdAt,
      updatedAt: DateTime.now(),
    );
    items[index] = item;
    return item;
  }

  @override
  Future<void> deleteNotice(String churchId, String noticeId) async =>
      _forChurch(churchId).removeWhere((item) => item.id == noticeId);
}
