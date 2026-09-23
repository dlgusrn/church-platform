#!/usr/bin/env python3
"""Create or reuse the development-only Local Playback Test video.

The script never updates existing videos and refuses every database except the
local development ``church_app`` database.
"""
from __future__ import annotations

import argparse
from datetime import UTC, datetime

from sqlalchemy import select
from sqlalchemy.engine import make_url

from app.core.config import get_settings
from app.core.database import get_session_factory
from app.models.church import Church
from app.models.video import Video, VideoSourceType
from app.services.video_sources.local_playback import LOCAL_PLAYBACK_SOURCE_REF

TITLE = "Local Playback Test"


def seed(*, church_code: str | None) -> tuple[Video, bool]:
    settings = get_settings()
    if settings.app_env.lower() != "development":
        raise SystemExit("Local playback seed is development-only")
    if make_url(settings.database_url).database != "church_app":
        raise SystemExit("Local playback seed only permits the church_app development database")
    with get_session_factory()() as session:
        church_query = select(Church).where(Church.is_active.is_(True))
        if church_code:
            church_query = church_query.where(Church.code == church_code)
        churches = list(session.scalars(church_query.order_by(Church.id)).all())
        if len(churches) != 1:
            raise SystemExit("Specify --church-code for exactly one active development church")
        church = churches[0]
        existing = session.scalar(select(Video).where(
            Video.church_id == church.id,
            Video.title == TITLE,
        ))
        if existing is not None:
            return existing, False
        video = Video(
            church_id=church.id,
            title=TITLE,
            source_type=VideoSourceType.SYNOLOGY,
            source_ref=LOCAL_PLAYBACK_SOURCE_REF,
            recorded_at=datetime.now(UTC),
            duration_seconds=24,
            is_published=True,
        )
        session.add(video)
        session.commit()
        session.refresh(video)
        return video, True


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--church-code", help="Active development church that the current admin belongs to")
    arguments = parser.parse_args()
    video, created = seed(church_code=arguments.church_code)
    print(f"Local Playback Test {'created' if created else 'reused'}: video id={video.id}")


if __name__ == "__main__":
    main()
