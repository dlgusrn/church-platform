import '../../../core/network/api_client.dart';
import '../../../core/network/api_model_mapper.dart';
import '../domain/notice_models.dart';
import 'notice_repository.dart';

class ApiNoticeRepository implements NoticeRepository {
  ApiNoticeRepository(this.client);
  final ApiClient client;

  @override
  Future<List<Notice>> listNotices(String churchId) async {
    try {
      return (await client.get('/api/v1/churches/$churchId/notices') as List)
          .map(_notice)
          .toList(growable: false);
    } on ApiException catch (error) {
      throw NoticeDataException(error.message);
    }
  }

  @override
  Future<Notice> getNotice(String churchId, String noticeId) =>
      _one(() => client.get('/api/v1/churches/$churchId/notices/$noticeId'));
  @override
  Future<Notice> createNotice(String churchId, NoticeDraft draft) => _one(
    () => client.post('/api/v1/churches/$churchId/notices', body: _body(draft)),
  );
  @override
  Future<Notice> updateNotice(
    String churchId,
    String noticeId,
    NoticeDraft draft,
  ) => _one(
    () => client.patch(
      '/api/v1/churches/$churchId/notices/$noticeId',
      body: _body(draft),
    ),
  );
  @override
  Future<void> deleteNotice(String churchId, String noticeId) async {
    try {
      await client.delete('/api/v1/churches/$churchId/notices/$noticeId');
    } on ApiException catch (error) {
      throw NoticeDataException(error.message);
    }
  }

  Future<Notice> _one(Future<dynamic> Function() request) async {
    try {
      return _notice(await request());
    } on ApiException catch (error) {
      throw NoticeDataException(error.message);
    }
  }

  static Map<String, dynamic> _body(NoticeDraft draft) => {
    'title': draft.title,
    'content': draft.content,
    'is_pinned': draft.isPinned,
  };
  static Notice _notice(dynamic json) {
    final map = ApiModelMapper.asMap(json);
    return Notice(
      id: '${map['id']}',
      churchId: '${map['church_id']}',
      title: map['title'] as String,
      content: map['content'] as String,
      isPinned: map['is_pinned'] as bool,
      publishedAt: DateTime.parse(map['published_at'] as String),
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }
}
