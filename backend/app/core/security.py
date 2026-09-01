from datetime import UTC, datetime, timedelta
from hashlib import sha256
from typing import Any, Literal
from uuid import uuid4

import jwt
from jwt import InvalidTokenError
from pwdlib import PasswordHash

from app.core.config import get_settings
from app.core.exceptions import AuthenticationError

TokenType = Literal["access", "refresh"]
_password_hash = PasswordHash.recommended()


def hash_password(password: str) -> str:
    return _password_hash.hash(password)


def verify_password(password: str, password_hash: str) -> bool:
    try:
        return _password_hash.verify(password, password_hash)
    except (ValueError, TypeError):
        return False


def hash_refresh_token(token: str) -> str:
    return sha256(token.encode("utf-8")).hexdigest()


def _create_token(
    subject: int | str,
    token_type: TokenType,
    expires_delta: timedelta,
    *,
    secret_key: str | None = None,
    algorithm: str | None = None,
    now: datetime | None = None,
) -> str:
    settings = None if secret_key is not None and algorithm is not None else get_settings()
    issued_at = now or datetime.now(UTC)
    payload: dict[str, Any] = {
        "sub": str(subject),
        "type": token_type,
        "iat": issued_at,
        "exp": issued_at + expires_delta,
        "jti": str(uuid4()),
    }
    return jwt.encode(
        payload,
        secret_key or settings.jwt_secret_key,  # type: ignore[union-attr]
        algorithm=algorithm or settings.jwt_algorithm,  # type: ignore[union-attr]
    )


def create_access_token(
    subject: int | str,
    *,
    secret_key: str | None = None,
    algorithm: str | None = None,
    expires_delta: timedelta | None = None,
) -> str:
    settings = get_settings() if expires_delta is None else None
    expiry = expires_delta or timedelta(minutes=settings.jwt_access_token_expire_minutes)
    return _create_token(subject, "access", expiry, secret_key=secret_key, algorithm=algorithm)


def create_refresh_token(
    subject: int | str,
    *,
    secret_key: str | None = None,
    algorithm: str | None = None,
    expires_delta: timedelta | None = None,
) -> str:
    settings = get_settings() if expires_delta is None else None
    expiry = expires_delta or timedelta(days=settings.jwt_refresh_token_expire_days)
    return _create_token(subject, "refresh", expiry, secret_key=secret_key, algorithm=algorithm)


def decode_token(
    token: str,
    expected_type: TokenType,
    *,
    secret_key: str | None = None,
    algorithm: str | None = None,
) -> dict[str, Any]:
    settings = None if secret_key is not None and algorithm is not None else get_settings()
    try:
        payload = jwt.decode(
            token,
            secret_key or settings.jwt_secret_key,  # type: ignore[union-attr]
            algorithms=[algorithm or settings.jwt_algorithm],  # type: ignore[union-attr]
            options={"require": ["sub", "type", "iat", "exp", "jti"]},
        )
    except InvalidTokenError as exc:
        raise AuthenticationError("Invalid or expired token") from exc
    if payload.get("type") != expected_type:
        raise AuthenticationError("Invalid token type")
    return payload
