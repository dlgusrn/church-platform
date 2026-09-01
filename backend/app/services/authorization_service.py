from sqlalchemy.orm import Session

from app.core.exceptions import ForbiddenError
from app.repositories.membership_repository import MembershipRepository
from app.services.permission_service import get_permission_breakdown


class AuthorizationService:
    def __init__(self, session: Session) -> None:
        self.memberships = MembershipRepository(session)

    def require_church_permission(
        self,
        *,
        user_id: int,
        church_id: int,
        permission_code: str,
    ) -> None:
        membership = self.memberships.get_by_user_and_church(user_id, church_id)
        if membership is None:
            raise ForbiddenError("Insufficient church permission")
        effective = get_permission_breakdown(membership).effective_permissions
        if permission_code not in effective:
            raise ForbiddenError("Insufficient church permission")
