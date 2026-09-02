from enum import StrEnum


class MembershipStatus(StrEnum):
    PENDING = "pending"
    APPROVED = "approved"
    REJECTED = "rejected"


class PermissionEffect(StrEnum):
    GRANT = "grant"
    DENY = "deny"


class LiveBroadcastStatus(StrEnum):
    SCHEDULED = "scheduled"
    LIVE = "live"
    ENDED = "ended"


class LiveWorshipType(StrEnum):
    DAY = "day"
    NIGHT = "night"
    PRAYER_11 = "prayer_11"
    SPECIAL = "special"
    CUSTOM = "custom"
