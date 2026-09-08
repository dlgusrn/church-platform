class PopupNoticeImage {
  const PopupNoticeImage({required this.contentType, required this.size, required this.url});
  final String contentType;
  final int size;
  final String url;
}

class PopupNotice {
  const PopupNotice({required this.id, required this.churchId, required this.authorMembershipId, required this.title, required this.content, required this.startsAt, required this.endsAt, required this.isActive, required this.createdAt, required this.updatedAt, this.image});
  final String id, churchId, authorMembershipId, title, content;
  final DateTime startsAt, endsAt, createdAt, updatedAt;
  final bool isActive;
  final PopupNoticeImage? image;
}

class PopupNoticeDraft {
  const PopupNoticeDraft({required this.title, required this.content, required this.startsAt, required this.endsAt, this.isActive = false});
  final String title, content;
  final DateTime startsAt, endsAt;
  final bool isActive;
}
