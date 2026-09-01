from datetime import UTC, datetime
import re

from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.core.exceptions import AuthenticationError, ConflictError
from app.core.security import (
    create_access_token,
    create_refresh_token,
    decode_token,
    hash_password,
    hash_refresh_token,
    verify_password,
)
from app.models.refresh_token import RefreshToken
from app.models.user import User
from app.repositories.refresh_token_repository import RefreshTokenRepository
from app.repositories.user_repository import UserRepository
from app.schemas.auth import LoginRequest, RefreshTokenRequest, RegisterRequest, TokenResponse


def normalize_email(email: str) -> str:
    return email.strip().lower()


def normalize_phone(phone: str) -> str:
    return re.sub(r"\D", "", phone)


class AuthService:
    def __init__(self, session: Session) -> None:
        self.session = session
        self.users = UserRepository(session)
        self.refresh_tokens = RefreshTokenRepository(session)

    def register(self, request: RegisterRequest) -> User:
        email = normalize_email(str(request.email)) if request.email is not None else None
        phone = normalize_phone(request.phone) if request.phone else None
        if email and self.users.get_by_email(email):
            raise ConflictError("Email is already registered")
        if phone and self.users.get_by_phone(phone):
            raise ConflictError("Phone is already registered")

        user = User(
            name=request.name.strip(),
            email=email,
            phone=phone,
            password_hash=hash_password(request.password),
        )
        try:
            self.users.add(user)
            self.session.commit()
        except IntegrityError as exc:
            self.session.rollback()
            raise ConflictError("Email or phone is already registered") from exc
        self.session.refresh(user)
        return user

    def login(self, request: LoginRequest) -> TokenResponse:
        user = self._find_by_identifier(request.identifier)
        if user is None or not user.is_active or not verify_password(request.password, user.password_hash):
            raise AuthenticationError("Invalid credentials")
        user.last_login_at = datetime.now(UTC)
        tokens = self._issue_token_pair(user.id)
        self.session.commit()
        return tokens

    def refresh(self, request: RefreshTokenRequest) -> TokenResponse:
        now = datetime.now(UTC)
        payload = decode_token(request.refresh_token, "refresh")
        try:
            user_id = int(payload["sub"])
        except (KeyError, TypeError, ValueError) as exc:
            raise AuthenticationError("Invalid refresh token") from exc

        stored = self.refresh_tokens.get_active(hash_refresh_token(request.refresh_token), now)
        user = self.users.get_by_id(user_id)
        if stored is None or stored.user_id != user_id or user is None or not user.is_active:
            raise AuthenticationError("Invalid refresh token")

        self.refresh_tokens.revoke(stored, now)
        tokens = self._issue_token_pair(user_id)
        self.session.commit()
        return tokens

    def _find_by_identifier(self, identifier: str) -> User | None:
        normalized = identifier.strip()
        if "@" in normalized:
            return self.users.get_by_email(normalize_email(normalized))
        phone = normalize_phone(normalized)
        return self.users.get_by_phone(phone) if phone else None

    def _issue_token_pair(self, user_id: int) -> TokenResponse:
        access_token = create_access_token(user_id)
        refresh_token = create_refresh_token(user_id)
        refresh_payload = decode_token(refresh_token, "refresh")
        expires_at = datetime.fromtimestamp(refresh_payload["exp"], tz=UTC)
        self.refresh_tokens.add(
            RefreshToken(
                user_id=user_id,
                token_hash=hash_refresh_token(refresh_token),
                expires_at=expires_at,
            )
        )
        return TokenResponse(access_token=access_token, refresh_token=refresh_token)
