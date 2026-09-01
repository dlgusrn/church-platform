from enum import StrEnum


class PermissionCode(StrEnum):
    LIVE_ACCESS = "live.access"
    VOD_VIEW = "vod.view"
    MEDIA_VIDEO_VIEW = "media.video.view"
    MEDIA_VIDEO_DOWNLOAD = "media.video.download"
    MEDIA_AUDIO_VIEW = "media.audio.view"
    MEDIA_AUDIO_DOWNLOAD = "media.audio.download"
    NOTICE_VIEW = "notice.view"
    NOTICE_CREATE = "notice.create"
    NOTICE_UPDATE = "notice.update"
    NOTICE_DELETE = "notice.delete"
    SCHEDULE_VIEW = "schedule.view"
    SCHEDULE_MANAGE = "schedule.manage"
    EXPENSE_VIEW = "expense.view"
    EXPENSE_CREATE = "expense.create"
    EXPENSE_UPDATE = "expense.update"
    EXPENSE_APPROVE = "expense.approve"
    APPROVAL_VIEW = "approval.view"
    APPROVAL_CREATE = "approval.create"
    APPROVAL_APPROVE = "approval.approve"
    ATTENDANCE_VIEW = "attendance.view"
    ATTENDANCE_MANAGE = "attendance.manage"
    DOCUMENT_VIEW = "document.view"
    DOCUMENT_CREATE = "document.create"
    DOCUMENT_MANAGE = "document.manage"
    MEMBER_VIEW = "member.view"
    MEMBER_MANAGE = "member.manage"
    ROLE_VIEW = "role.view"
    ROLE_MANAGE = "role.manage"
    PERMISSION_MANAGE = "permission.manage"
    CHURCH_MANAGE = "church.manage"


PERMISSION_V1: tuple[tuple[PermissionCode, str], ...] = tuple(
    (code, code.value) for code in PermissionCode
)
