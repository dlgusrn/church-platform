from fastapi import APIRouter, status

from app.dependencies.auth import DatabaseSession
from app.dependencies.permissions import ChurchMembershipRequired, LiveManagePermission
from app.schemas.live_broadcast import (
    LiveBroadcastCreateRequest,
    LiveBroadcastResponse,
    LiveBroadcastUpdateRequest,
)
from app.services.live_broadcast_service import LiveBroadcastService

router = APIRouter()


@router.get("/current", response_model=LiveBroadcastResponse | None)
def get_current_live_broadcast(
    church_id: int,
    _membership: ChurchMembershipRequired,
    session: DatabaseSession,
) -> LiveBroadcastResponse | None:
    return LiveBroadcastService(session).current(church_id)


@router.get("", response_model=list[LiveBroadcastResponse])
def list_live_broadcasts(
    church_id: int,
    _permission: LiveManagePermission,
    session: DatabaseSession,
) -> list[LiveBroadcastResponse]:
    return LiveBroadcastService(session).list_broadcasts(church_id)


@router.post("", response_model=LiveBroadcastResponse, status_code=status.HTTP_201_CREATED)
def create_live_broadcast(
    church_id: int,
    request: LiveBroadcastCreateRequest,
    _permission: LiveManagePermission,
    session: DatabaseSession,
) -> LiveBroadcastResponse:
    return LiveBroadcastService(session).create(church_id, request)


@router.patch("/{broadcast_id}", response_model=LiveBroadcastResponse)
def update_live_broadcast(
    church_id: int,
    broadcast_id: int,
    request: LiveBroadcastUpdateRequest,
    _permission: LiveManagePermission,
    session: DatabaseSession,
) -> LiveBroadcastResponse:
    return LiveBroadcastService(session).update(church_id, broadcast_id, request)
