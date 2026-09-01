from fastapi import APIRouter

from app.dependencies.auth import CurrentUser, DatabaseSession
from app.schemas.membership import PermissionBreakdownResponse
from app.services.membership_service import MembershipService

router = APIRouter()


@router.get("/{membership_id}/permissions", response_model=PermissionBreakdownResponse)
def get_membership_permissions(
    membership_id: int,
    current_user: CurrentUser,
    session: DatabaseSession,
) -> PermissionBreakdownResponse:
    return MembershipService(session).get_permissions(membership_id, current_user.id)
