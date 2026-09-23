from sqlalchemy import extract, func, select
from sqlalchemy.orm import Session

from app.models.video import Video, VideoCategory, VideoCollection, VideoSourceType


class VideoRepository:
    def __init__(self, session: Session) -> None:
        self.session = session

    def list_for_church(
        self,
        church_id: int,
        *,
        year: int | None = None,
        month: int | None = None,
        category_id: int | None = None,
        collection_id: int | None = None,
        published: bool | None = None,
    ) -> list[Video]:
        statement = select(Video).where(Video.church_id == church_id)
        if year is not None:
            statement = statement.where(extract("year", Video.recorded_at) == year)
        if month is not None:
            statement = statement.where(extract("month", Video.recorded_at) == month)
        if category_id is not None:
            statement = statement.where(Video.category_id == category_id)
        if collection_id is not None:
            statement = statement.where(Video.collection_id == collection_id)
        if published is not None:
            statement = statement.where(Video.is_published.is_(published))
        return list(self.session.scalars(statement.order_by(Video.recorded_at.desc(), Video.id.desc())).all())

    def list_page_for_church(
        self,
        church_id: int,
        *,
        published: bool | None,
        offset: int,
        limit: int,
    ) -> tuple[list[Video], int]:
        conditions = [Video.church_id == church_id]
        if published is not None:
            conditions.append(Video.is_published.is_(published))
        statement = select(Video).where(*conditions)
        total = int(self.session.scalar(select(func.count(Video.id)).where(*conditions)) or 0)
        items = list(self.session.scalars(statement.order_by(Video.recorded_at.desc(), Video.id.desc()).offset(offset).limit(limit)).all())
        return items, total

    def get_for_church(self, video_id: int, church_id: int, *, for_update: bool = False) -> Video | None:
        statement = select(Video).where(Video.id == video_id, Video.church_id == church_id)
        if for_update:
            statement = statement.with_for_update()
        return self.session.scalar(statement)

    def get_by_source_for_church(self, church_id: int, source_type: VideoSourceType, source_ref: str, *, exclude_id: int | None = None) -> Video | None:
        statement = select(Video).where(
            Video.church_id == church_id,
            Video.source_type == source_type,
            Video.source_ref == source_ref,
        )
        if exclude_id is not None:
            statement = statement.where(Video.id != exclude_id)
        return self.session.scalar(statement)

    def archive_for_church(self, church_id: int, *, published: bool | None = None) -> list[tuple[int, int, int]]:
        year = extract("year", Video.recorded_at).label("year")
        month = extract("month", Video.recorded_at).label("month")
        statement = select(year, month, func.count(Video.id).label("video_count")).where(Video.church_id == church_id)
        if published is not None:
            statement = statement.where(Video.is_published.is_(published))
        rows = self.session.execute(
            statement.group_by(year, month).order_by(year.desc(), month.desc())
        ).all()
        return [(int(row.year), int(row.month), int(row.video_count)) for row in rows]

    def add_video(self, video: Video) -> Video:
        self.session.add(video)
        self.session.flush()
        return video

    def delete_video(self, video: Video) -> None:
        self.session.delete(video)

    def list_categories(self, church_id: int, *, active_only: bool = False) -> list[VideoCategory]:
        statement = select(VideoCategory).where(VideoCategory.church_id == church_id)
        if active_only:
            statement = statement.where(VideoCategory.is_active.is_(True))
        return list(self.session.scalars(statement.order_by(VideoCategory.sort_order, VideoCategory.id)).all())

    def get_category_for_church(self, category_id: int, church_id: int, *, for_update: bool = False) -> VideoCategory | None:
        statement = select(VideoCategory).where(VideoCategory.id == category_id, VideoCategory.church_id == church_id)
        if for_update:
            statement = statement.with_for_update()
        return self.session.scalar(statement)

    def add_category(self, category: VideoCategory) -> VideoCategory:
        self.session.add(category)
        self.session.flush()
        return category

    def list_collections(self, church_id: int, *, published: bool | None = None) -> list[VideoCollection]:
        statement = select(VideoCollection).where(VideoCollection.church_id == church_id)
        if published is not None:
            statement = statement.where(VideoCollection.is_published.is_(published))
        return list(self.session.scalars(
            statement.order_by(VideoCollection.sort_order, VideoCollection.recorded_at.desc(), VideoCollection.id.desc())
        ).all())

    def get_collection_for_church(self, collection_id: int, church_id: int, *, for_update: bool = False) -> VideoCollection | None:
        statement = select(VideoCollection).where(VideoCollection.id == collection_id, VideoCollection.church_id == church_id)
        if for_update:
            statement = statement.with_for_update()
        return self.session.scalar(statement)

    def add_collection(self, collection: VideoCollection) -> VideoCollection:
        self.session.add(collection)
        self.session.flush()
        return collection

    def delete_collection(self, collection: VideoCollection) -> None:
        self.session.delete(collection)
