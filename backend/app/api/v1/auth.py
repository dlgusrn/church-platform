from typing import Annotated

from fastapi import APIRouter, Depends, status
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.schemas.auth import LoginRequest, RefreshTokenRequest, RegisterRequest, TokenResponse
from app.schemas.user import UserResponse
from app.services.auth_service import AuthService

router = APIRouter()
DatabaseSession = Annotated[Session, Depends(get_db)]


@router.post("/register", response_model=UserResponse, status_code=status.HTTP_201_CREATED)
def register(request: RegisterRequest, session: DatabaseSession) -> UserResponse:
    return UserResponse.model_validate(AuthService(session).register(request))


@router.post("/login", response_model=TokenResponse)
def login(request: LoginRequest, session: DatabaseSession) -> TokenResponse:
    return AuthService(session).login(request)


@router.post("/refresh", response_model=TokenResponse)
def refresh(request: RefreshTokenRequest, session: DatabaseSession) -> TokenResponse:
    return AuthService(session).refresh(request)
