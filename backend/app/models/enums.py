from enum import StrEnum


class MembershipStatus(StrEnum):
    PENDING = "pending"
    APPROVED = "approved"
    REJECTED = "rejected"


class PermissionEffect(StrEnum):
    GRANT = "grant"
    DENY = "deny"
