from fastapi import APIRouter

from app.dependencies.auth import CurrentUser, DatabaseSession
from app.schemas.membership import MembershipResponse
from app.schemas.user import UserResponse
from app.services.membership_service import MembershipService

router = APIRouter()


@router.get("/me", response_model=UserResponse)
def get_me(current_user: CurrentUser) -> UserResponse:
    return UserResponse.model_validate(current_user)


@router.get("/me/memberships", response_model=list[MembershipResponse])
def get_my_memberships(
    current_user: CurrentUser,
    session: DatabaseSession,
) -> list[MembershipResponse]:
    return MembershipService(session).list_my_memberships(current_user.id)
