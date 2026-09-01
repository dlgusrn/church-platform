from collections.abc import Iterable, Mapping
from dataclasses import dataclass

from app.models.enums import MembershipStatus, PermissionEffect
from app.models.membership import ChurchMembership


@dataclass(frozen=True)
class PermissionBreakdown:
    role_permissions: set[str]
    granted_permissions: set[str]
    denied_permissions: set[str]
    effective_permissions: set[str]


def calculate_effective_permissions(
    *,
    membership_status: MembershipStatus,
    role_permissions: Iterable[str] = (),
    overrides: Mapping[str, PermissionEffect] | Iterable[tuple[str, PermissionEffect]] = (),
) -> set[str]:
    if membership_status is not MembershipStatus.APPROVED:
        return set()

    effective = set(role_permissions)
    override_items = overrides.items() if isinstance(overrides, Mapping) else overrides
    for permission_code, effect in override_items:
        if effect is PermissionEffect.GRANT:
            effective.add(permission_code)
        elif effect is PermissionEffect.DENY:
            effective.discard(permission_code)
    return effective


def get_permission_breakdown(membership: ChurchMembership) -> PermissionBreakdown:
    role_permissions = {
        permission.code for permission in membership.role.permissions
    } if membership.role is not None else set()
    granted_permissions = {
        override.permission.code
        for override in membership.permission_overrides
        if override.effect is PermissionEffect.GRANT
    }
    denied_permissions = {
        override.permission.code
        for override in membership.permission_overrides
        if override.effect is PermissionEffect.DENY
    }
    effective_permissions = calculate_effective_permissions(
        membership_status=membership.status,
        role_permissions=role_permissions,
        overrides=[
            (override.permission.code, override.effect)
            for override in membership.permission_overrides
        ],
    )
    return PermissionBreakdown(
        role_permissions=role_permissions,
        granted_permissions=granted_permissions,
        denied_permissions=denied_permissions,
        effective_permissions=effective_permissions,
    )
