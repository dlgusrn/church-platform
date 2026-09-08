from fastapi import APIRouter

from app.api.v1 import (
    auth,
    churches,
    health,
    live_broadcasts,
    memberships,
    notices,
    popup_notices,
    users,
    videos,
    worship_schedules,
)

router = APIRouter()
router.include_router(health.router, tags=["health"])
router.include_router(auth.router, prefix="/auth", tags=["auth"])
router.include_router(users.router, prefix="/users", tags=["users"])
router.include_router(churches.router, prefix="/churches", tags=["churches"])
router.include_router(memberships.router, prefix="/memberships", tags=["memberships"])
router.include_router(
    notices.router,
    prefix="/churches/{church_id}/notices",
    tags=["notices"],
)
router.include_router(
    popup_notices.router,
    prefix="/churches/{church_id}/popup-notices",
    tags=["popup-notices"],
)
router.include_router(
    worship_schedules.router,
    prefix="/churches/{church_id}/worship-schedules",
    tags=["worship-schedules"],
)
router.include_router(
    live_broadcasts.router,
    prefix="/churches/{church_id}/live-broadcasts",
    tags=["live-broadcasts"],
)
router.include_router(
    videos.videos_router,
    prefix="/churches/{church_id}/videos",
    tags=["videos"],
)
router.include_router(
    videos.categories_router,
    prefix="/churches/{church_id}/video-categories",
    tags=["video-categories"],
)
router.include_router(
    videos.collections_router,
    prefix="/churches/{church_id}/video-collections",
    tags=["video-collections"],
)
