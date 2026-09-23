from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.core.exceptions import ConflictError, ForbiddenError, NotFoundError, RequestValidationError
from app.core.permission_codes import PermissionCode
from app.models.video import Video, VideoCategory, VideoCollection
from app.repositories.church_repository import ChurchRepository
from app.repositories.membership_repository import MembershipRepository
from app.repositories.video_repository import VideoRepository
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
    VideoReviewPageRead,
    VideoBulkPublishRead,
    VideoUpdate,
    YouTubeVideoCreate,
)
from app.models.video import VideoSourceType
from app.services.video_sources import parse_youtube_url
from app.services.permission_service import get_permission_breakdown


class VideoService:
    def __init__(self, session: Session) -> None:
        self.session = session
        self.churches = ChurchRepository(session)
        self.memberships = MembershipRepository(session)
        self.videos = VideoRepository(session)

    def list_videos(self, church_id: int, user_id: int, **filters: int | bool | None) -> list[VideoRead]:
        self._require_church(church_id)
        if not self._has_manage_permission(church_id, user_id):
            self._require_read_permission(church_id, user_id)
            if filters.get("published") is False:
                raise ForbiddenError("Unpublished videos require video management permission")
            # Never trust a client filter to broaden a viewer's library.
            filters["published"] = True
        elif filters.get("published") is None:
            filters["published"] = True
        return [self._video_response(video, public=True) for video in self.videos.list_for_church(church_id, **filters)]

    def get_video(self, church_id: int, video_id: int, user_id: int) -> VideoRead:
        self._require_church(church_id)
        can_manage = self._has_manage_permission(church_id, user_id)
        if not can_manage:
            # Preserve church-isolation behavior before looking up an ID.
            self._require_read_permission(church_id, user_id)
        video = self._video_or_raise(church_id, video_id)
        if not video.is_published and not can_manage:
            raise NotFoundError("Video not found")
        return self._video_response(video, public=True)

    def archive(self, church_id: int, user_id: int, *, published: bool | None = None) -> list[VideoArchiveResponse]:
        self._require_church(church_id)
        if not self._has_manage_permission(church_id, user_id):
            self._require_read_permission(church_id, user_id)
            if published is False:
                raise ForbiddenError("Unpublished videos require video management permission")
            published = True
        elif published is None:
            published = True
        return [VideoArchiveResponse(year=year, month=month, video_count=count) for year, month, count in self.videos.archive_for_church(church_id, published=published)]

    def review_videos(self, church_id: int, user_id: int, *, status: str, offset: int, limit: int) -> VideoReviewPageRead:
        self._require_church(church_id)
        self._require_manage_permission(church_id, user_id)
        if status not in {"all", "published", "unpublished"}:
            raise RequestValidationError("Video review status is invalid")
        published = {"published": True, "unpublished": False}.get(status)
        items, total = self.videos.list_page_for_church(church_id, published=published, offset=offset, limit=limit)
        published_count = len(self.videos.list_for_church(church_id, published=True))
        unpublished_count = len(self.videos.list_for_church(church_id, published=False))
        return VideoReviewPageRead(
            items=[self._video_response(video, public=True) for video in items],
            total=total,
            published_count=published_count,
            unpublished_count=unpublished_count,
            offset=offset,
            limit=limit,
        )

    def bulk_publish(self, church_id: int, user_id: int, video_ids: list[int]) -> VideoBulkPublishRead:
        self._require_church(church_id)
        self._require_manage_permission(church_id, user_id)
        requested = list(dict.fromkeys(video_ids))
        published = already_published = failed = 0
        items: list[dict[str, object]] = []
        try:
            for video_id in requested:
                video = self.videos.get_for_church(video_id, church_id, for_update=True)
                if video is None:
                    failed += 1
                    items.append({"status": "failed", "video_id": video_id, "error_code": "video_not_found"})
                elif video.is_published:
                    already_published += 1
                    items.append({"status": "already_published", "video_id": video_id, "error_code": None})
                else:
                    video.is_published = True
                    published += 1
                    items.append({"status": "published", "video_id": video_id, "error_code": None})
            self.session.commit()
        except Exception:
            self.session.rollback()
            raise
        return VideoBulkPublishRead(
            requested_count=len(requested),
            published_count=published,
            already_published_count=already_published,
            failed_count=failed,
            items=items,
        )

    def create_video(self, church_id: int, user_id: int, request: VideoCreate) -> VideoRead:
        self._require_church(church_id)
        self._require_manage_permission(church_id, user_id)
        values = request.model_dump()
        self._validate_references(church_id, values)
        self._assert_unique_source(church_id, values)
        try:
            video = self.videos.add_video(Video(church_id=church_id, **values))
            self.session.commit()
        except IntegrityError as exc:
            self.session.rollback()
            raise ConflictError("A video with this source already exists in the church") from exc
        return self._video_response(video)

    def create_youtube_video(self, church_id: int, user_id: int, request: YouTubeVideoCreate) -> VideoRead:
        source = parse_youtube_url(request.url)
        values = request.model_dump(exclude={"url"})
        values.update(source_type=VideoSourceType.YOUTUBE, source_ref=source.video_id, thumbnail_ref=source.thumbnail_ref)
        return self.create_video(church_id, user_id, VideoCreate(**values))

    def update_video(self, church_id: int, video_id: int, user_id: int, request: VideoUpdate) -> VideoRead:
        self._require_church(church_id)
        self._require_manage_permission(church_id, user_id)
        try:
            video = self._video_or_raise(church_id, video_id, for_update=True)
            values = request.model_dump(exclude_unset=True)
            self._validate_references(church_id, values)
            next_source_type = values.get("source_type", video.source_type)
            next_source_ref = values.get("source_ref", video.source_ref)
            self._assert_unique_source(church_id, {"source_type": next_source_type, "source_ref": next_source_ref}, exclude_id=video.id)
            for field, value in values.items():
                setattr(video, field, value)
            self.session.commit()
        except IntegrityError as exc:
            self.session.rollback()
            raise ConflictError("A video with this source already exists in the church") from exc
        return self._video_response(video)

    def delete_video(self, church_id: int, video_id: int, user_id: int) -> None:
        self._require_church(church_id)
        self._require_manage_permission(church_id, user_id)
        video = self._video_or_raise(church_id, video_id, for_update=True)
        self.videos.delete_video(video)
        self.session.commit()

    def list_categories(self, church_id: int, user_id: int) -> list[VideoCategoryRead]:
        self._require_church(church_id)
        self._require_read_permission(church_id, user_id)
        return [VideoCategoryRead.model_validate(category) for category in self.videos.list_categories(church_id)]

    def create_category(self, church_id: int, user_id: int, request: VideoCategoryCreate) -> VideoCategoryRead:
        self._require_church(church_id)
        self._require_manage_permission(church_id, user_id)
        try:
            category = self.videos.add_category(VideoCategory(church_id=church_id, **request.model_dump()))
            self.session.commit()
        except IntegrityError as exc:
            self.session.rollback()
            raise ConflictError("A video category with this name already exists in the church") from exc
        return VideoCategoryRead.model_validate(category)

    def update_category(self, church_id: int, category_id: int, user_id: int, request: VideoCategoryUpdate) -> VideoCategoryRead:
        self._require_church(church_id)
        self._require_manage_permission(church_id, user_id)
        try:
            category = self._category_or_raise(church_id, category_id, for_update=True)
            for field, value in request.model_dump(exclude_unset=True).items():
                setattr(category, field, value)
            self.session.commit()
        except IntegrityError as exc:
            self.session.rollback()
            raise ConflictError("A video category with this name already exists in the church") from exc
        return VideoCategoryRead.model_validate(category)

    def deactivate_category(self, church_id: int, category_id: int, user_id: int) -> VideoCategoryRead:
        return self.update_category(church_id, category_id, user_id, VideoCategoryUpdate(is_active=False))

    def list_collections(self, church_id: int, user_id: int) -> list[VideoCollectionRead]:
        self._require_church(church_id)
        self._require_read_permission(church_id, user_id)
        return [VideoCollectionRead.model_validate(collection) for collection in self.videos.list_collections(church_id)]

    def get_collection(self, church_id: int, collection_id: int, user_id: int) -> VideoCollectionRead:
        self._require_church(church_id)
        self._require_read_permission(church_id, user_id)
        return VideoCollectionRead.model_validate(self._collection_or_raise(church_id, collection_id))

    def create_collection(self, church_id: int, user_id: int, request: VideoCollectionCreate) -> VideoCollectionRead:
        self._require_church(church_id)
        self._require_manage_permission(church_id, user_id)
        values = request.model_dump()
        self._validate_category_reference(church_id, values.get("category_id"))
        collection = self.videos.add_collection(VideoCollection(church_id=church_id, **values))
        self.session.commit()
        return VideoCollectionRead.model_validate(collection)

    def update_collection(self, church_id: int, collection_id: int, user_id: int, request: VideoCollectionUpdate) -> VideoCollectionRead:
        self._require_church(church_id)
        self._require_manage_permission(church_id, user_id)
        collection = self._collection_or_raise(church_id, collection_id, for_update=True)
        values = request.model_dump(exclude_unset=True)
        if "category_id" in values:
            self._validate_category_reference(church_id, values["category_id"])
        for field, value in values.items():
            setattr(collection, field, value)
        self.session.commit()
        return VideoCollectionRead.model_validate(collection)

    def delete_collection(self, church_id: int, collection_id: int, user_id: int) -> None:
        self._require_church(church_id)
        self._require_manage_permission(church_id, user_id)
        collection = self._collection_or_raise(church_id, collection_id, for_update=True)
        # The database FK is ON DELETE SET NULL: only video metadata loses its collection link.
        self.videos.delete_collection(collection)
        self.session.commit()

    def _require_read_permission(self, church_id: int, user_id: int) -> None:
        self._require_any_permission(church_id, user_id, {PermissionCode.VOD_VIEW.value, PermissionCode.MEDIA_VIDEO_VIEW.value})

    def _require_manage_permission(self, church_id: int, user_id: int) -> None:
        self._require_any_permission(church_id, user_id, {PermissionCode.MEDIA_VIDEO_MANAGE.value})

    def _has_manage_permission(self, church_id: int, user_id: int) -> bool:
        membership = self.memberships.get_by_user_and_church(user_id, church_id)
        return membership is not None and PermissionCode.MEDIA_VIDEO_MANAGE.value in get_permission_breakdown(membership).effective_permissions

    def _require_any_permission(self, church_id: int, user_id: int, required: set[str]) -> None:
        membership = self.memberships.get_by_user_and_church(user_id, church_id)
        if membership is None or not (get_permission_breakdown(membership).effective_permissions & required):
            raise ForbiddenError("Insufficient church permission")

    def _validate_references(self, church_id: int, values: dict[str, object]) -> None:
        if "category_id" in values:
            self._validate_category_reference(church_id, values["category_id"])
        if "collection_id" in values:
            self._validate_collection_reference(church_id, values["collection_id"])

    def _validate_category_reference(self, church_id: int, category_id: object) -> None:
        if category_id is None:
            return
        category = self.videos.get_category_for_church(int(category_id), church_id)
        if category is None:
            raise RequestValidationError("Video category must belong to this church")
        if not category.is_active:
            raise RequestValidationError("Video category is inactive")

    def _validate_collection_reference(self, church_id: int, collection_id: object) -> None:
        if collection_id is None:
            return
        if self.videos.get_collection_for_church(int(collection_id), church_id) is None:
            raise RequestValidationError("Video collection must belong to this church")

    def _assert_unique_source(self, church_id: int, values: dict[str, object], *, exclude_id: int | None = None) -> None:
        if self.videos.get_by_source_for_church(church_id, values["source_type"], str(values["source_ref"]), exclude_id=exclude_id):  # type: ignore[arg-type]
            raise ConflictError("A video with this source already exists in the church")

    def _video_or_raise(self, church_id: int, video_id: int, *, for_update: bool = False) -> Video:
        video = self.videos.get_for_church(video_id, church_id, for_update=for_update)
        if video is None:
            raise NotFoundError("Video not found")
        return video

    @staticmethod
    def _video_response(video: Video, *, public: bool = False) -> VideoRead:
        response = VideoRead.model_validate(video)
        if public and video.source_type == VideoSourceType.SYNOLOGY:
            response.source_ref = None
        if video.source_type == VideoSourceType.YOUTUBE:
            response.playback = {"type": "youtube", "video_id": video.source_ref}
        return response

    def _category_or_raise(self, church_id: int, category_id: int, *, for_update: bool = False) -> VideoCategory:
        category = self.videos.get_category_for_church(category_id, church_id, for_update=for_update)
        if category is None:
            raise NotFoundError("Video category not found")
        return category

    def _collection_or_raise(self, church_id: int, collection_id: int, *, for_update: bool = False) -> VideoCollection:
        collection = self.videos.get_collection_for_church(collection_id, church_id, for_update=for_update)
        if collection is None:
            raise NotFoundError("Video collection not found")
        return collection

    def _require_church(self, church_id: int) -> None:
        church = self.churches.get_by_id(church_id)
        if church is None or not church.is_active:
            raise NotFoundError("Church not found")
