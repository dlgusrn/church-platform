from datetime import UTC, datetime

from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.core.exceptions import (
    ApplicationError,
    ConflictError,
    ForbiddenError,
    NotFoundError,
    RequestValidationError,
)
from app.models.enums import MembershipStatus, PermissionEffect
from app.models.membership import ChurchMembership
from app.models.permission_override import MembershipPermissionOverride
from app.models.role import Role
from app.repositories.church_repository import ChurchRepository
from app.repositories.membership_repository import MembershipRepository
from app.repositories.permission_repository import PermissionRepository
from app.repositories.role_repository import RoleRepository
from app.schemas.church import ChurchResponse
from app.schemas.membership import (
    MembershipManagementResponse,
    MembershipPermissionUpdateRequest,
    MembershipResponse,
    PendingMembershipResponse,
    PermissionBreakdownResponse,
    RoleSummary,
    UserSummary,
)
from app.services.authorization_service import AuthorizationService
from app.services.permission_service import PermissionBreakdown, get_permission_breakdown


class MembershipService:
    def __init__(self, session: Session) -> None:
        self.session = session
        self.churches = ChurchRepository(session)
        self.memberships = MembershipRepository(session)
        self.roles = RoleRepository(session)
        self.permissions = PermissionRepository(session)

    def request_membership(self, user_id: int, church_id: int) -> MembershipResponse:
        church = self.churches.get_by_id(church_id)
        if church is None or not church.is_active:
            raise NotFoundError("Church not found")
        now = datetime.now(UTC)
        membership = self.memberships.get_by_user_and_church(
            user_id, church_id, for_update=True
        )
        if membership is not None and membership.status in {
            MembershipStatus.PENDING,
            MembershipStatus.APPROVED,
        }:
            raise ConflictError("Membership already exists")
        try:
            if membership is None:
                membership = self.memberships.add(
                    ChurchMembership(
                        user_id=user_id,
                        church_id=church_id,
                        status=MembershipStatus.PENDING,
                        requested_at=now,
                    )
                )
                membership.church = church
            else:
                self.memberships.clear_overrides(membership)
                membership.status = MembershipStatus.PENDING
                membership.role_id = None
                membership.role = None
                membership.requested_at = now
                membership.approved_at = None
                membership.rejected_at = None
            self.session.commit()
        except IntegrityError as exc:
            self.session.rollback()
            raise ConflictError("Membership already exists") from exc
        return self._membership_response(membership, PermissionBreakdown(set(), set(), set(), set()))

    def list_my_memberships(self, user_id: int) -> list[MembershipResponse]:
        return [
            self._membership_response(item, get_permission_breakdown(item))
            for item in self.memberships.list_for_user(user_id)
        ]

    def list_pending(self, church_id: int) -> list[PendingMembershipResponse]:
        return [
            PendingMembershipResponse(
                membership_id=item.id,
                user=UserSummary.model_validate(item.user, from_attributes=True),
                church=ChurchResponse.model_validate(item.church),
                status=item.status,
                requested_at=item.requested_at,
            )
            for item in self.memberships.list_pending(church_id)
        ]

    def get_permissions(self, membership_id: int, current_user_id: int) -> PermissionBreakdownResponse:
        membership = self.memberships.get_by_id(membership_id)
        if membership is None:
            raise NotFoundError("Membership not found")
        if membership.user_id != current_user_id:
            AuthorizationService(self.session).require_church_permission(
                user_id=current_user_id,
                church_id=membership.church_id,
                permission_code="permission.manage",
            )
        return self._breakdown_response(get_permission_breakdown(membership))

    def approve(
        self,
        church_id: int,
        membership_id: int,
        request: MembershipPermissionUpdateRequest,
    ) -> MembershipManagementResponse:
        membership = self._locked_target(church_id, membership_id)
        if membership.status is not MembershipStatus.PENDING:
            raise ApplicationError("Only pending memberships can be approved")
        return self._assign_permissions(membership, request, approve=True)

    def reject(self, church_id: int, membership_id: int) -> MembershipResponse:
        membership = self._locked_target(church_id, membership_id)
        if membership.status is not MembershipStatus.PENDING:
            raise ApplicationError("Only pending memberships can be rejected")
        self.memberships.clear_overrides(membership)
        membership.status = MembershipStatus.REJECTED
        membership.role_id = None
        membership.role = None
        membership.approved_at = None
        membership.rejected_at = datetime.now(UTC)
        self.session.commit()
        return self._membership_response(membership, PermissionBreakdown(set(), set(), set(), set()))

    def update_permissions(
        self,
        church_id: int,
        membership_id: int,
        request: MembershipPermissionUpdateRequest,
    ) -> MembershipManagementResponse:
        membership = self._locked_target(church_id, membership_id)
        if membership.status is not MembershipStatus.APPROVED:
            raise ApplicationError("Only approved memberships can be updated")
        return self._assign_permissions(membership, request, approve=False)

    def _locked_target(self, church_id: int, membership_id: int) -> ChurchMembership:
        membership = self.memberships.get_by_id(membership_id, for_update=True)
        if membership is None or membership.church_id != church_id:
            raise NotFoundError("Membership not found")
        return membership

    def _assign_permissions(
        self,
        membership: ChurchMembership,
        request: MembershipPermissionUpdateRequest,
        *,
        approve: bool,
    ) -> MembershipManagementResponse:
        role = self.roles.get_assignable(request.role_id, membership.church_id)
        if role is None:
            raise NotFoundError("Role not found")
        requested_codes = set(request.granted_permissions) | set(request.denied_permissions)
        permissions = self.permissions.get_by_codes(requested_codes)
        unknown_codes = requested_codes - set(permissions)
        if unknown_codes:
            raise RequestValidationError(
                f"Unknown permission codes: {sorted(unknown_codes)}"
            )
        # Flush delete-orphans before constructing replacements. Otherwise a
        # transient override linked to a persistent Permission can be observed
        # by the DELETE-triggered flush before it has joined this Session.
        self.memberships.clear_overrides(membership)
        overrides = [
            MembershipPermissionOverride(
                membership=membership,
                permission=permissions[code],
                effect=effect,
            )
            for effect, codes in (
                (PermissionEffect.GRANT, request.granted_permissions),
                (PermissionEffect.DENY, request.denied_permissions),
            )
            for code in codes
        ]
        self.memberships.add_overrides(overrides)
        membership.role_id = role.id
        membership.role = role
        if approve:
            membership.status = MembershipStatus.APPROVED
            membership.approved_at = datetime.now(UTC)
            membership.rejected_at = None
        self.session.commit()
        breakdown = PermissionBreakdown(
            role_permissions={permission.code for permission in role.permissions},
            granted_permissions=set(request.granted_permissions),
            denied_permissions=set(request.denied_permissions),
            effective_permissions=(
                {permission.code for permission in role.permissions}
                | set(request.granted_permissions)
            ) - set(request.denied_permissions),
        )
        return self._management_response(membership, breakdown)

    @staticmethod
    def _breakdown_response(breakdown: PermissionBreakdown) -> PermissionBreakdownResponse:
        return PermissionBreakdownResponse(
            role_permissions=sorted(breakdown.role_permissions),
            granted_permissions=sorted(breakdown.granted_permissions),
            denied_permissions=sorted(breakdown.denied_permissions),
            effective_permissions=sorted(breakdown.effective_permissions),
        )

    def _membership_response(
        self, membership: ChurchMembership, breakdown: PermissionBreakdown
    ) -> MembershipResponse:
        return MembershipResponse(
            membership_id=membership.id,
            church=ChurchResponse.model_validate(membership.church),
            status=membership.status,
            role=self._role_summary(membership.role),
            requested_at=membership.requested_at,
            approved_at=membership.approved_at,
            effective_permissions=sorted(breakdown.effective_permissions),
        )

    def _management_response(
        self, membership: ChurchMembership, breakdown: PermissionBreakdown
    ) -> MembershipManagementResponse:
        return MembershipManagementResponse(
            **self._membership_response(membership, breakdown).model_dump(),
            role_permissions=sorted(breakdown.role_permissions),
            granted_permissions=sorted(breakdown.granted_permissions),
            denied_permissions=sorted(breakdown.denied_permissions),
        )

    @staticmethod
    def _role_summary(role: Role | None) -> RoleSummary | None:
        if role is None:
            return None
        return RoleSummary(id=role.id, code=role.code, name=role.name, is_system=role.is_system)
