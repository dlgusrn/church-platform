from sqlalchemy import select
from sqlalchemy.orm import Session, selectinload

from app.models.enums import MembershipStatus
from app.models.membership import ChurchMembership
from app.models.permission_override import MembershipPermissionOverride
from app.models.role import Role


def membership_load_options() -> tuple[object, ...]:
    return (
        selectinload(ChurchMembership.church),
        selectinload(ChurchMembership.user),
        selectinload(ChurchMembership.role).selectinload(Role.permissions),
        selectinload(ChurchMembership.permission_overrides).selectinload(
            MembershipPermissionOverride.permission
        ),
    )


class MembershipRepository:
    def __init__(self, session: Session) -> None:
        self.session = session

    def get_by_user_and_church(
        self, user_id: int, church_id: int, *, for_update: bool = False
    ) -> ChurchMembership | None:
        statement = select(ChurchMembership).where(
            ChurchMembership.user_id == user_id,
            ChurchMembership.church_id == church_id,
        )
        if for_update:
            statement = statement.with_for_update()
        return self.session.scalar(
            statement.options(*membership_load_options()).execution_options(populate_existing=True)
        )

    def get_by_id(self, membership_id: int, *, for_update: bool = False) -> ChurchMembership | None:
        statement = select(ChurchMembership).where(ChurchMembership.id == membership_id)
        if for_update:
            statement = statement.with_for_update()
        return self.session.scalar(
            statement.options(*membership_load_options()).execution_options(populate_existing=True)
        )

    def list_for_user(self, user_id: int) -> list[ChurchMembership]:
        return list(
            self.session.scalars(
                select(ChurchMembership)
                .where(ChurchMembership.user_id == user_id)
                .options(*membership_load_options())
                .execution_options(populate_existing=True)
                .order_by(ChurchMembership.church_id, ChurchMembership.id)
            ).all()
        )

    def list_pending(self, church_id: int) -> list[ChurchMembership]:
        return list(
            self.session.scalars(
                select(ChurchMembership)
                .where(
                    ChurchMembership.church_id == church_id,
                    ChurchMembership.status == MembershipStatus.PENDING,
                )
                .options(*membership_load_options())
                .execution_options(populate_existing=True)
                .order_by(ChurchMembership.requested_at, ChurchMembership.id)
            ).all()
        )

    def add(self, membership: ChurchMembership) -> ChurchMembership:
        self.session.add(membership)
        self.session.flush()
        return membership

    def clear_overrides(self, membership: ChurchMembership) -> None:
        membership.permission_overrides.clear()
        self.session.flush()

    def add_overrides(self, overrides: list[MembershipPermissionOverride]) -> None:
        self.session.add_all(overrides)
        self.session.flush()
