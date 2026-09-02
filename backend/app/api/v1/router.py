from fastapi import APIRouter

from app.api.v1 import (
    auth,
    churches,
    health,
    live_broadcasts,
    memberships,
    users,
    worship_schedules,
)

router = APIRouter()
router.include_router(health.router, tags=["health"])
router.include_router(auth.router, prefix="/auth", tags=["auth"])
router.include_router(users.router, prefix="/users", tags=["users"])
router.include_router(churches.router, prefix="/churches", tags=["churches"])
router.include_router(memberships.router, prefix="/memberships", tags=["memberships"])
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
