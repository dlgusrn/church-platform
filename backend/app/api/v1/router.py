from fastapi import APIRouter

from app.api.v1 import auth, churches, health, memberships, users

router = APIRouter()
router.include_router(health.router, tags=["health"])
router.include_router(auth.router, prefix="/auth", tags=["auth"])
router.include_router(users.router, prefix="/users", tags=["users"])
router.include_router(churches.router, prefix="/churches", tags=["churches"])
router.include_router(memberships.router, prefix="/memberships", tags=["memberships"])
