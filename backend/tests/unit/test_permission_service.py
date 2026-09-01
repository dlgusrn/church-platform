from app.models.enums import MembershipStatus, PermissionEffect
from app.services.permission_service import calculate_effective_permissions


def test_approved_membership_gets_role_permissions() -> None:
    assert calculate_effective_permissions(
        membership_status=MembershipStatus.APPROVED,
        role_permissions={"live.access", "vod.view"},
    ) == {"live.access", "vod.view"}


def test_grant_and_deny_overrides() -> None:
    assert calculate_effective_permissions(
        membership_status=MembershipStatus.APPROVED,
        role_permissions={"live.access", "vod.view"},
        overrides={
            "media.audio.view": PermissionEffect.GRANT,
            "vod.view": PermissionEffect.DENY,
        },
    ) == {"live.access", "media.audio.view"}


def test_pending_membership_has_no_permissions() -> None:
    assert calculate_effective_permissions(
        membership_status=MembershipStatus.PENDING,
        role_permissions={"live.access", "vod.view"},
        overrides={"media.audio.view": PermissionEffect.GRANT},
    ) == set()


def test_rejected_membership_has_no_permissions() -> None:
    assert calculate_effective_permissions(
        membership_status=MembershipStatus.REJECTED,
        role_permissions={"live.access", "vod.view"},
        overrides={"media.audio.view": PermissionEffect.GRANT},
    ) == set()
