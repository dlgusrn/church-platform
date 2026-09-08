import '../domain/popup_notice_models.dart';

abstract interface class PopupNoticeRepository {
  Future<List<PopupNotice>> list(String churchId);
  Future<PopupNotice> get(String churchId, String id);
  Future<PopupNotice> create(String churchId, PopupNoticeDraft draft);
  Future<PopupNotice> update(String churchId, String id, PopupNoticeDraft draft);
  Future<void> delete(String churchId, String id);
  Future<PopupNotice> setActive(String churchId, String id, bool value);
  Future<PopupNotice?> current(String churchId);
  Future<PopupNotice> uploadImage(String churchId, String id, List<int> bytes, String filename);
  Future<PopupNotice> removeImage(String churchId, String id);
  Future<List<int>> imageBytes(String relativePath);
}

class PopupNoticeDataException implements Exception {
  const PopupNoticeDataException(this.message, {this.code});
  final String message;
  final String? code;
  @override String toString() => message;
}
