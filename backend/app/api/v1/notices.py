from fastapi import APIRouter, Response, status

from app.dependencies.auth import CurrentUser, DatabaseSession
from app.dependencies.permissions import (
    ApprovedChurchMembership,
    NoticeCreatePermission,
    NoticeDeletePermission,
    NoticeUpdatePermission,
    NoticeViewPermission,
)
from app.schemas.notice import NoticeCreateRequest, NoticeResponse, NoticeUpdateRequest
from app.services.notice_service import NoticeService

router = APIRouter()


@router.get("", response_model=list[NoticeResponse])
def list_notices(
    church_id: int,
    _membership: ApprovedChurchMembership,
    _permission: NoticeViewPermission,
    session: DatabaseSession,
) -> list[NoticeResponse]:
    return NoticeService(session).list_notices(church_id)


@router.get("/{notice_id}", response_model=NoticeResponse)
def get_notice(
    church_id: int,
    notice_id: int,
    _membership: ApprovedChurchMembership,
    _permission: NoticeViewPermission,
    session: DatabaseSession,
) -> NoticeResponse:
    return NoticeService(session).get_notice(church_id, notice_id)


@router.post("", response_model=NoticeResponse, status_code=status.HTTP_201_CREATED)
def create_notice(
    church_id: int,
    request: NoticeCreateRequest,
    current_user: CurrentUser,
    _membership: ApprovedChurchMembership,
    _permission: NoticeCreatePermission,
    session: DatabaseSession,
) -> NoticeResponse:
    return NoticeService(session).create(church_id, current_user.id, request)


@router.patch("/{notice_id}", response_model=NoticeResponse)
def update_notice(
    church_id: int,
    notice_id: int,
    request: NoticeUpdateRequest,
    _membership: ApprovedChurchMembership,
    _permission: NoticeUpdatePermission,
    session: DatabaseSession,
) -> NoticeResponse:
    return NoticeService(session).update(church_id, notice_id, request)


@router.delete("/{notice_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_notice(
    church_id: int,
    notice_id: int,
    _membership: ApprovedChurchMembership,
    _permission: NoticeDeletePermission,
    session: DatabaseSession,
) -> Response:
    NoticeService(session).delete(church_id, notice_id)
    return Response(status_code=status.HTTP_204_NO_CONTENT)
