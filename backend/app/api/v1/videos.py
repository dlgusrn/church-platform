from fastapi import APIRouter, Query, Response, status

from app.dependencies.auth import CurrentUser, DatabaseSession
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
)
from app.services.video_service import VideoService
from app.services.video_sources.synology.service import SynologyImportService

videos_router = APIRouter()
categories_router = APIRouter()
collections_router = APIRouter()


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


@videos_router.get("/{video_id}", response_model=VideoRead)
def get_video(church_id: int, video_id: int, current_user: CurrentUser, session: DatabaseSession) -> VideoRead:
    return VideoService(session).get_video(church_id, video_id, current_user.id)


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
def synology_preview(church_id: int, current_user: CurrentUser, session: DatabaseSession, offset: int = Query(0, ge=0), limit: int = Query(100, ge=1, le=200)) -> SynologyPreviewRead:
    service = VideoService(session); service._require_church(church_id); service._require_manage_permission(church_id, current_user.id)
    token, candidates, summary = SynologyImportService(session).preview(church_id, offset=offset, limit=limit)
    return SynologyPreviewRead(snapshot_token=token, summary=summary, candidates=candidates, offset=offset, limit=limit)


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
