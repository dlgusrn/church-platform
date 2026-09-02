enum AppPermission {
  liveAccess('live.access'),
  liveManage('live.manage'),
  vodView('vod.view'),
  mediaVideoView('media.video.view'),
  mediaVideoDownload('media.video.download'),
  mediaAudioView('media.audio.view'),
  mediaAudioDownload('media.audio.download'),
  noticeView('notice.view'),
  noticeCreate('notice.create'),
  noticeUpdate('notice.update'),
  noticeDelete('notice.delete'),
  scheduleView('schedule.view'),
  scheduleManage('schedule.manage'),
  expenseView('expense.view'),
  expenseCreate('expense.create'),
  expenseUpdate('expense.update'),
  expenseApprove('expense.approve'),
  approvalView('approval.view'),
  approvalCreate('approval.create'),
  approvalApprove('approval.approve'),
  attendanceView('attendance.view'),
  attendanceManage('attendance.manage'),
  documentView('document.view'),
  documentCreate('document.create'),
  documentManage('document.manage'),
  memberView('member.view'),
  memberManage('member.manage'),
  roleView('role.view'),
  roleManage('role.manage'),
  permissionManage('permission.manage'),
  churchManage('church.manage');

  const AppPermission(this.code);
  final String code;

  static AppPermission? fromCode(String code) {
    for (final permission in values) {
      if (permission.code == code) return permission;
    }
    return null;
  }

  static Set<AppPermission> parseCodes(Iterable<dynamic> codes) {
    final result = <AppPermission>{};
    for (final code in codes) {
      if (code is! String) continue;
      final permission = fromCode(code);
      if (permission != null) result.add(permission);
    }
    return result;
  }
}

const videoNavigationPermissions = {
  AppPermission.vodView,
  AppPermission.mediaVideoView,
};
const workNavigationPermissions = {
  AppPermission.noticeView,
  AppPermission.noticeCreate,
  AppPermission.noticeUpdate,
  AppPermission.noticeDelete,
  AppPermission.scheduleView,
  AppPermission.scheduleManage,
  AppPermission.expenseView,
  AppPermission.expenseCreate,
  AppPermission.expenseUpdate,
  AppPermission.expenseApprove,
  AppPermission.approvalView,
  AppPermission.approvalCreate,
  AppPermission.approvalApprove,
  AppPermission.attendanceView,
  AppPermission.attendanceManage,
  AppPermission.documentView,
  AppPermission.documentCreate,
  AppPermission.documentManage,
};
