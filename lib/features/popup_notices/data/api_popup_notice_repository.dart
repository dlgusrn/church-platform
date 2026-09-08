import '../../../core/network/api_client.dart';
import '../../../core/network/api_model_mapper.dart';
import '../domain/popup_notice_models.dart';
import 'popup_notice_repository.dart';

class ApiPopupNoticeRepository implements PopupNoticeRepository {
  ApiPopupNoticeRepository(this.client);
  final ApiClient client;
  String _base(String churchId) => '/api/v1/churches/$churchId/popup-notices';
  @override Future<List<PopupNotice>> list(String churchId) => _call(() async => (await client.get(_base(churchId)) as List).map(_item).toList());
  @override Future<PopupNotice> get(String c, String id) => _call(() async => _item(await client.get('${_base(c)}/$id')));
  @override Future<PopupNotice> create(String c, PopupNoticeDraft d) => _call(() async => _item(await client.post(_base(c), body: _body(d))));
  @override Future<PopupNotice> update(String c, String id, PopupNoticeDraft d) => _call(() async => _item(await client.patch('${_base(c)}/$id', body: _body(d))));
  @override Future<void> delete(String c, String id) => _call(() async { await client.delete('${_base(c)}/$id'); });
  @override Future<PopupNotice> setActive(String c, String id, bool v) => _call(() async => _item(await client.patch('${_base(c)}/$id/active', body: {'is_active': v})));
  @override Future<PopupNotice?> current(String c) => _call(() async { final json = await client.get('${_base(c)}/current'); return json == null ? null : _item(json); });
  @override Future<PopupNotice> uploadImage(String c, String id, List<int> b, String name) => _call(() async => _item(await client.putMultipart('${_base(c)}/$id/image', bytes: b, filename: name)));
  @override Future<PopupNotice> removeImage(String c, String id) => _call(() async => _item(await client.delete('${_base(c)}/$id/image')));
  @override Future<List<int>> imageBytes(String relativePath) => _call(() => client.getBytes(relativePath));
  Future<T> _call<T>(Future<T> Function() work) async { try { return await work(); } on ApiException catch (e) { final details = e.details; final code = details is Map ? details['code'] as String? : null; throw PopupNoticeDataException(e.message, code: code); } }
  static Map<String, dynamic> _body(PopupNoticeDraft d) => {'title': d.title, 'content': d.content, 'starts_at': d.startsAt.toUtc().toIso8601String(), 'ends_at': d.endsAt.toUtc().toIso8601String(), 'is_active': d.isActive};
  static PopupNotice _item(dynamic json) { final m = ApiModelMapper.asMap(json); final image = m['image'] as Map?; return PopupNotice(id: '${m['id']}', churchId: '${m['church_id']}', authorMembershipId: '${m['author_membership_id']}', title: m['title'] as String, content: m['content'] as String, startsAt: DateTime.parse(m['starts_at'] as String), endsAt: DateTime.parse(m['ends_at'] as String), isActive: m['is_active'] as bool, createdAt: DateTime.parse(m['created_at'] as String), updatedAt: DateTime.parse(m['updated_at'] as String), image: image == null ? null : PopupNoticeImage(contentType: image['content_type'] as String, size: image['size'] as int, url: image['url'] as String)); }
}
