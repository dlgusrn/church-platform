from fastapi import APIRouter, status

from app.dependencies.auth import CurrentUser, DatabaseSession
from app.dependencies.permissions import (
    MemberManagePermission,
    MemberViewPermission,
    PermissionManagePermission,
    RoleViewPermission,
)
from app.schemas.church import ChurchResponse
from app.schemas.membership import (
    MembershipManagementResponse,
    MembershipPermissionUpdateRequest,
    MembershipResponse,
    PendingMembershipResponse,
)
from app.schemas.role import RoleResponse
from app.services.church_service import ChurchService
from app.services.membership_service import MembershipService

router = APIRouter()


@router.get("", response_model=list[ChurchResponse])
def list_churches(current_user: CurrentUser, session: DatabaseSession) -> list[ChurchResponse]:
    return ChurchService(session).list_churches()


@router.post(
    "/{church_id}/memberships",
    response_model=MembershipResponse,
    status_code=status.HTTP_201_CREATED,
)
def request_membership(
    church_id: int,
    current_user: CurrentUser,
    session: DatabaseSession,
) -> MembershipResponse:
    return MembershipService(session).request_membership(current_user.id, church_id)


@router.get(
    "/{church_id}/memberships/pending",
    response_model=list[PendingMembershipResponse],
)
def list_pending_memberships(
    church_id: int,
    _permission: MemberViewPermission,
    session: DatabaseSession,
) -> list[PendingMembershipResponse]:
    return MembershipService(session).list_pending(church_id)


@router.post(
    "/{church_id}/memberships/{membership_id}/approve",
    response_model=MembershipManagementResponse,
)
def approve_membership(
    church_id: int,
    membership_id: int,
    request: MembershipPermissionUpdateRequest,
    _permission: MemberManagePermission,
    session: DatabaseSession,
) -> MembershipManagementResponse:
    return MembershipService(session).approve(church_id, membership_id, request)


@router.post(
    "/{church_id}/memberships/{membership_id}/reject",
    response_model=MembershipResponse,
)
def reject_membership(
    church_id: int,
    membership_id: int,
    _permission: MemberManagePermission,
    session: DatabaseSession,
) -> MembershipResponse:
    return MembershipService(session).reject(church_id, membership_id)


@router.patch(
    "/{church_id}/memberships/{membership_id}/permissions",
    response_model=MembershipManagementResponse,
)
def update_membership_permissions(
    church_id: int,
    membership_id: int,
    request: MembershipPermissionUpdateRequest,
    _permission: PermissionManagePermission,
    session: DatabaseSession,
) -> MembershipManagementResponse:
    return MembershipService(session).update_permissions(church_id, membership_id, request)


@router.get("/{church_id}/roles", response_model=list[RoleResponse])
def list_roles(
    church_id: int,
    _permission: RoleViewPermission,
    session: DatabaseSession,
) -> list[RoleResponse]:
    return ChurchService(session).list_roles(church_id)
