from typing import Annotated

from fastapi import APIRouter, Depends, Header, Query, Response, status
from fastapi.responses import JSONResponse, StreamingResponse
from sqlalchemy.orm import Session

from app.dependencies.auth import CurrentUser, DatabaseSession
from app.core.database import get_playback_session
from app.core.exceptions import AuthenticationError
from app.schemas.video import (
    VideoArchiveResponse,
    VideoCategoryCreate,
    VideoCategoryRead,
    VideoCategoryUpdate,
    VideoCollectionCreate,
    VideoCollectionRead,
    VideoCollectionUpdate,
    VideoCreate,
    VideoRead,
    VideoUpdate,
    YouTubeVideoCreate,
    SynologyConnectionRead, SynologyPreviewRead, SynologyImportRequest, SynologyImportRead,
    VideoPlaybackSessionRead,
    VideoReviewPageRead, VideoBulkPublishRequest, VideoBulkPublishRead,
)
from app.services.video_service import VideoService
from app.services.video_sources.synology.service import SynologyImportService
from app.services.video_playback_service import (
    PlaybackRangeError,
    PlaybackRangeErrorWithHeaders,
    PlaybackUpstreamError,
    VideoPlaybackService,
)

videos_router = APIRouter()
playback_router = APIRouter()
categories_router = APIRouter()
collections_router = APIRouter()

# Streaming responses keep ordinary request-scoped yield dependencies open until
# the body has been sent. This provider is explicitly closed by the endpoint
# after authorization and before a stream can be returned.
PlaybackDatabaseSession = Annotated[Session, Depends(get_playback_session)]


@videos_router.get("/archive", response_model=list[VideoArchiveResponse])
def video_archive(
    church_id: int,
    current_user: CurrentUser,
    session: DatabaseSession,
    published: bool | None = None,
) -> list[VideoArchiveResponse]:
    return VideoService(session).archive(church_id, current_user.id, published=published)


@videos_router.get("", response_model=list[VideoRead])
def list_videos(
    church_id: int,
    current_user: CurrentUser,
    session: DatabaseSession,
    year: int | None = None,
    month: int | None = Query(default=None, ge=1, le=12),
    category_id: int | None = None,
    collection_id: int | None = None,
    published: bool | None = None,
) -> list[VideoRead]:
    return VideoService(session).list_videos(
        church_id, current_user.id, year=year, month=month,
        category_id=category_id, collection_id=collection_id, published=published,
    )


@videos_router.get("/review", response_model=VideoReviewPageRead)
def review_videos(
    church_id: int,
    current_user: CurrentUser,
    session: DatabaseSession,
    status_filter: str = Query(default="unpublished", alias="status"),
    offset: int = Query(default=0, ge=0),
    limit: int = Query(default=100, ge=1, le=200),
) -> VideoReviewPageRead:
    return VideoService(session).review_videos(church_id, current_user.id, status=status_filter, offset=offset, limit=limit)


@videos_router.post("/bulk-publish", response_model=VideoBulkPublishRead)
def bulk_publish_videos(
    church_id: int,
    request: VideoBulkPublishRequest,
    current_user: CurrentUser,
    session: DatabaseSession,
) -> VideoBulkPublishRead:
    return VideoService(session).bulk_publish(church_id, current_user.id, request.video_ids)


@videos_router.get("/{video_id}", response_model=VideoRead)
def get_video(church_id: int, video_id: int, current_user: CurrentUser, session: DatabaseSession) -> VideoRead:
    return VideoService(session).get_video(church_id, video_id, current_user.id)


@videos_router.post("/{video_id}/playback-session", response_model=VideoPlaybackSessionRead)
def create_playback_session(
    church_id: int, video_id: int, current_user: CurrentUser, session: DatabaseSession,
) -> VideoPlaybackSessionRead:
    token, expires_at = VideoPlaybackService(session).create_session(church_id, video_id, current_user.id)
    # Deliberately relative: Flutter resolves this against its configured API
    # base URL; the credential is header-only and never part of this URL.
    return VideoPlaybackSessionRead(
        playback_url="/api/v1/playback",
        playback_token=token,
        expires_at=expires_at,
    )


async def _playback_response(
    playback_token: str,
    session: Session,
    range_header: str | None,
    method: str,
) -> StreamingResponse | JSONResponse:
    try:
        VideoPlaybackService.validate_range(range_header)
        try:
            # Descriptor contains no ORM objects and is safe after this close.
            descriptor = VideoPlaybackService(session).prepare_stream(playback_token)
        finally:
            # Must happen before opening the Synology stream / returning its
            # StreamingResponse, including failed authorization paths.
            session.close()
        return await VideoPlaybackService(None).stream_prepared(descriptor, range_header=range_header, method=method)
    except PlaybackRangeErrorWithHeaders as exc:
        return JSONResponse(status_code=416, content={"detail": "Requested video range is unavailable"}, headers=exc.headers)
    except PlaybackRangeError:
        return JSONResponse(status_code=416, content={"detail": "Requested video range is invalid"})
    except PlaybackUpstreamError as exc:
        return JSONResponse(status_code=exc.status_code, content={"detail": "Video source is temporarily unavailable"})


@playback_router.get("/playback", include_in_schema=False, response_model=None)
async def stream_playback(
    session: PlaybackDatabaseSession,
    playback_token: str | None = Header(default=None, alias="X-Playback-Token"),
    range_header: str | None = Header(default=None, alias="Range"),
) -> StreamingResponse | JSONResponse:
    try:
        if not playback_token:
            raise AuthenticationError("Playback token required")
        return await _playback_response(playback_token, session, range_header, "GET")
    finally:
        # Covers the missing-header path, which has no authorization phase.
        session.close()


@playback_router.head("/playback", include_in_schema=False, response_model=None)
async def head_playback(
    session: PlaybackDatabaseSession,
    playback_token: str | None = Header(default=None, alias="X-Playback-Token"),
    range_header: str | None = Header(default=None, alias="Range"),
) -> StreamingResponse | JSONResponse:
    try:
        if not playback_token:
            raise AuthenticationError("Playback token required")
        return await _playback_response(playback_token, session, range_header, "HEAD")
    finally:
        session.close()


@videos_router.post("", response_model=VideoRead, status_code=status.HTTP_201_CREATED)
def create_video(church_id: int, request: VideoCreate, current_user: CurrentUser, session: DatabaseSession) -> VideoRead:
    return VideoService(session).create_video(church_id, current_user.id, request)

@videos_router.post("/youtube", response_model=VideoRead, status_code=status.HTTP_201_CREATED)
def create_youtube_video(church_id: int, request: YouTubeVideoCreate, current_user: CurrentUser, session: DatabaseSession) -> VideoRead:
    return VideoService(session).create_youtube_video(church_id, current_user.id, request)


@videos_router.post("/synology/connection-test", response_model=SynologyConnectionRead)
def synology_connection_test(church_id: int, current_user: CurrentUser, session: DatabaseSession) -> SynologyConnectionRead:
    service = VideoService(session); service._require_church(church_id); service._require_manage_permission(church_id, current_user.id)
    return SynologyConnectionRead(**SynologyImportService(session).connection_test())


@videos_router.post("/synology/preview", response_model=SynologyPreviewRead)
def synology_preview(
    church_id: int,
    current_user: CurrentUser,
    session: DatabaseSession,
    snapshot_token: str | None = Query(default=None, min_length=16, max_length=100),
    offset: int = Query(0, ge=0),
    limit: int = Query(100, ge=1, le=200),
    status_filter: str = Query(default="all", alias="status"),
    folder: str | None = Query(default=None, max_length=500),
) -> SynologyPreviewRead:
    service = VideoService(session); service._require_church(church_id); service._require_manage_permission(church_id, current_user.id)
    token, candidates, summary, folder_facets, selectable_source_refs = SynologyImportService(session).preview(
        church_id,
        snapshot_token=snapshot_token,
        offset=offset,
        limit=limit,
        status_filter=status_filter,
        folder=folder,
    )
    return SynologyPreviewRead(snapshot_token=token, summary=summary, candidates=candidates, folder_facets=folder_facets, selectable_source_refs=selectable_source_refs, offset=offset, limit=limit)


@videos_router.post("/synology/import", response_model=SynologyImportRead)
def synology_import(church_id: int, request: SynologyImportRequest, current_user: CurrentUser, session: DatabaseSession) -> SynologyImportRead:
    service = VideoService(session); service._require_church(church_id); service._require_manage_permission(church_id, current_user.id)
    return SynologyImportRead(**SynologyImportService(session).import_candidates(church_id, request.snapshot_token, request.source_refs))


@videos_router.patch("/{video_id}", response_model=VideoRead)
def update_video(church_id: int, video_id: int, request: VideoUpdate, current_user: CurrentUser, session: DatabaseSession) -> VideoRead:
    return VideoService(session).update_video(church_id, video_id, current_user.id, request)


@videos_router.delete("/{video_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_video(church_id: int, video_id: int, current_user: CurrentUser, session: DatabaseSession) -> Response:
    VideoService(session).delete_video(church_id, video_id, current_user.id)
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@categories_router.get("", response_model=list[VideoCategoryRead])
def list_categories(church_id: int, current_user: CurrentUser, session: DatabaseSession) -> list[VideoCategoryRead]:
    return VideoService(session).list_categories(church_id, current_user.id)


@categories_router.post("", response_model=VideoCategoryRead, status_code=status.HTTP_201_CREATED)
def create_category(church_id: int, request: VideoCategoryCreate, current_user: CurrentUser, session: DatabaseSession) -> VideoCategoryRead:
    return VideoService(session).create_category(church_id, current_user.id, request)


@categories_router.patch("/{category_id}", response_model=VideoCategoryRead)
def update_category(church_id: int, category_id: int, request: VideoCategoryUpdate, current_user: CurrentUser, session: DatabaseSession) -> VideoCategoryRead:
    return VideoService(session).update_category(church_id, category_id, current_user.id, request)


@categories_router.delete("/{category_id}", response_model=VideoCategoryRead)
def deactivate_category(church_id: int, category_id: int, current_user: CurrentUser, session: DatabaseSession) -> VideoCategoryRead:
    return VideoService(session).deactivate_category(church_id, category_id, current_user.id)


@collections_router.get("", response_model=list[VideoCollectionRead])
def list_collections(church_id: int, current_user: CurrentUser, session: DatabaseSession) -> list[VideoCollectionRead]:
    return VideoService(session).list_collections(church_id, current_user.id)


@collections_router.get("/{collection_id}", response_model=VideoCollectionRead)
def get_collection(church_id: int, collection_id: int, current_user: CurrentUser, session: DatabaseSession) -> VideoCollectionRead:
    return VideoService(session).get_collection(church_id, collection_id, current_user.id)


@collections_router.post("", response_model=VideoCollectionRead, status_code=status.HTTP_201_CREATED)
def create_collection(church_id: int, request: VideoCollectionCreate, current_user: CurrentUser, session: DatabaseSession) -> VideoCollectionRead:
    return VideoService(session).create_collection(church_id, current_user.id, request)


@collections_router.patch("/{collection_id}", response_model=VideoCollectionRead)
def update_collection(church_id: int, collection_id: int, request: VideoCollectionUpdate, current_user: CurrentUser, session: DatabaseSession) -> VideoCollectionRead:
    return VideoService(session).update_collection(church_id, collection_id, current_user.id, request)


@collections_router.delete("/{collection_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_collection(church_id: int, collection_id: int, current_user: CurrentUser, session: DatabaseSession) -> Response:
    VideoService(session).delete_collection(church_id, collection_id, current_user.id)
    return Response(status_code=status.HTTP_204_NO_CONTENT)
