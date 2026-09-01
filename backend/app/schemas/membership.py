from datetime import datetime
from typing import Self

from pydantic import BaseModel, Field, model_validator

from app.models.enums import MembershipStatus
from app.schemas.church import ChurchResponse


class RoleSummary(BaseModel):
    id: int
    code: str
    name: str
    is_system: bool


class UserSummary(BaseModel):
    id: int
    name: str
    email: str | None
    phone: str | None


class MembershipResponse(BaseModel):
    membership_id: int
    church: ChurchResponse
    status: MembershipStatus
    role: RoleSummary | None
    requested_at: datetime
    approved_at: datetime | None
    effective_permissions: list[str]


class PendingMembershipResponse(BaseModel):
    membership_id: int
    user: UserSummary
    church: ChurchResponse
    status: MembershipStatus
    requested_at: datetime


class PermissionBreakdownResponse(BaseModel):
    role_permissions: list[str]
    granted_permissions: list[str]
    denied_permissions: list[str]
    effective_permissions: list[str]


class MembershipPermissionUpdateRequest(BaseModel):
    role_id: int
    granted_permissions: list[str] = Field(default_factory=list)
    denied_permissions: list[str] = Field(default_factory=list)

    @model_validator(mode="after")
    def validate_permission_sets(self) -> Self:
        granted = set(self.granted_permissions)
        denied = set(self.denied_permissions)
        if len(granted) != len(self.granted_permissions):
            raise ValueError("granted_permissions contains duplicates")
        if len(denied) != len(self.denied_permissions):
            raise ValueError("denied_permissions contains duplicates")
        overlap = granted & denied
        if overlap:
            raise ValueError(f"permissions cannot be both granted and denied: {sorted(overlap)}")
        return self


class MembershipManagementResponse(MembershipResponse):
    role_permissions: list[str]
    granted_permissions: list[str]
    denied_permissions: list[str]
