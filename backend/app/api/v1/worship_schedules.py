from fastapi import APIRouter, Query, status

from app.dependencies.auth import CurrentUser, DatabaseSession
from app.dependencies.permissions import (
    ScheduleManagePermission,
    ScheduleViewPermission,
)
from app.schemas.worship_schedule import (
    WorshipScheduleCreateRequest,
    WorshipScheduleResponse,
    WorshipScheduleUpdateRequest,
)
from app.services.authorization_service import AuthorizationService
from app.services.worship_schedule_service import WorshipScheduleService

router = APIRouter()


@router.get("", response_model=list[WorshipScheduleResponse])
def list_worship_schedules(
    church_id: int,
    current_user: CurrentUser,
    session: DatabaseSession,
    _permission: ScheduleViewPermission,
    include_inactive: bool = Query(default=False),
) -> list[WorshipScheduleResponse]:
    if include_inactive:
        AuthorizationService(session).require_church_permission(
            user_id=current_user.id,
            church_id=church_id,
            permission_code="schedule.manage",
        )
    return WorshipScheduleService(session).list_schedules(
        church_id, include_inactive=include_inactive
    )


@router.post("", response_model=WorshipScheduleResponse, status_code=status.HTTP_201_CREATED)
def create_worship_schedule(
    church_id: int,
    request: WorshipScheduleCreateRequest,
    _permission: ScheduleManagePermission,
    session: DatabaseSession,
) -> WorshipScheduleResponse:
    return WorshipScheduleService(session).create(church_id, request)


@router.patch("/{schedule_id}", response_model=WorshipScheduleResponse)
def update_worship_schedule(
    church_id: int,
    schedule_id: int,
    request: WorshipScheduleUpdateRequest,
    _permission: ScheduleManagePermission,
    session: DatabaseSession,
) -> WorshipScheduleResponse:
    return WorshipScheduleService(session).update(church_id, schedule_id, request)
