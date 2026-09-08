from fastapi import APIRouter, File, Response, UploadFile, status

from app.dependencies.auth import CurrentUser, DatabaseSession
from app.dependencies.permissions import ApprovedChurchMembership, PopupNoticeManagePermission
from app.schemas.popup_notice import PopupNoticeActiveRequest, PopupNoticeCreateRequest, PopupNoticeResponse, PopupNoticeUpdateRequest
from app.services.popup_notice_service import PopupNoticeService
from app.services.media_storage import MAX_IMAGE_BYTES

router = APIRouter()


@router.get("/current", response_model=PopupNoticeResponse | None)
def current_popup_notice(church_id: int, _membership: ApprovedChurchMembership, session: DatabaseSession) -> PopupNoticeResponse | None:
    return PopupNoticeService(session).current(church_id)


@router.get("", response_model=list[PopupNoticeResponse])
def list_popup_notices(church_id: int, _permission: PopupNoticeManagePermission, session: DatabaseSession) -> list[PopupNoticeResponse]:
    return PopupNoticeService(session).list_notices(church_id)


@router.post("", response_model=PopupNoticeResponse, status_code=status.HTTP_201_CREATED)
def create_popup_notice(church_id: int, request: PopupNoticeCreateRequest, current_user: CurrentUser, _permission: PopupNoticeManagePermission, session: DatabaseSession) -> PopupNoticeResponse:
    return PopupNoticeService(session).create(church_id, current_user.id, request)


@router.get("/{popup_notice_id}", response_model=PopupNoticeResponse)
def get_popup_notice(church_id: int, popup_notice_id: int, _permission: PopupNoticeManagePermission, session: DatabaseSession) -> PopupNoticeResponse:
    return PopupNoticeService(session).get_notice(church_id, popup_notice_id)


@router.patch("/{popup_notice_id}", response_model=PopupNoticeResponse)
def update_popup_notice(church_id: int, popup_notice_id: int, request: PopupNoticeUpdateRequest, _permission: PopupNoticeManagePermission, session: DatabaseSession) -> PopupNoticeResponse:
    return PopupNoticeService(session).update(church_id, popup_notice_id, request)


@router.patch("/{popup_notice_id}/active", response_model=PopupNoticeResponse)
def set_popup_notice_active(church_id: int, popup_notice_id: int, request: PopupNoticeActiveRequest, _permission: PopupNoticeManagePermission, session: DatabaseSession) -> PopupNoticeResponse:
    return PopupNoticeService(session).set_active(church_id, popup_notice_id, request)


@router.delete("/{popup_notice_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_popup_notice(church_id: int, popup_notice_id: int, _permission: PopupNoticeManagePermission, session: DatabaseSession) -> Response:
    PopupNoticeService(session).delete(church_id, popup_notice_id)
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.put("/{popup_notice_id}/image", response_model=PopupNoticeResponse)
async def replace_popup_notice_image(
    church_id: int,
    popup_notice_id: int,
    _permission: PopupNoticeManagePermission,
    session: DatabaseSession,
    image: UploadFile = File(...),
) -> PopupNoticeResponse:
    # Bound the in-memory request payload before image decoding/validation.
    data = await image.read(MAX_IMAGE_BYTES + 1)
    return PopupNoticeService(session).replace_image(church_id, popup_notice_id, data, image.filename)


@router.delete("/{popup_notice_id}/image", response_model=PopupNoticeResponse)
def remove_popup_notice_image(church_id: int, popup_notice_id: int, _permission: PopupNoticeManagePermission, session: DatabaseSession) -> PopupNoticeResponse:
    return PopupNoticeService(session).remove_image(church_id, popup_notice_id)


@router.get("/{popup_notice_id}/image")
def get_popup_notice_image(church_id: int, popup_notice_id: int, _membership: ApprovedChurchMembership, session: DatabaseSession) -> Response:
    data, content_type = PopupNoticeService(session).image_bytes(church_id, popup_notice_id)
    return Response(content=data, media_type=content_type)
