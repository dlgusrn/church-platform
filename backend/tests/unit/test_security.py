from datetime import UTC, datetime, timedelta

import pytest

from app.core.exceptions import AuthenticationError
from app.core.security import (
    create_access_token,
    create_refresh_token,
    create_video_playback_token,
    decode_token,
    hash_password,
    hash_refresh_token,
    verify_password,
)

SECRET = "unit-test-secret-that-is-long-enough"


def test_password_hash_and_verify() -> None:
    encoded = hash_password("correct horse battery staple")
    assert encoded != "correct horse battery staple"
    assert verify_password("correct horse battery staple", encoded)
    assert not verify_password("wrong", encoded)


def test_access_token_create_and_decode() -> None:
    token = create_access_token(
        42,
        secret_key=SECRET,
        algorithm="HS256",
        expires_delta=timedelta(minutes=5),
    )
    payload = decode_token(token, "access", secret_key=SECRET, algorithm="HS256")
    assert payload["sub"] == "42"
    assert payload["type"] == "access"
    assert "permissions" not in payload
    assert "roles" not in payload


def test_refresh_token_create_decode_and_hash() -> None:
    token = create_refresh_token(
        7,
        secret_key=SECRET,
        algorithm="HS256",
        expires_delta=timedelta(days=1),
    )
    payload = decode_token(token, "refresh", secret_key=SECRET, algorithm="HS256")
    assert payload["sub"] == "7"
    assert payload["type"] == "refresh"
    assert hash_refresh_token(token) != token
    assert len(hash_refresh_token(token)) == 64


def test_token_type_is_enforced() -> None:
    token = create_access_token(
        1,
        secret_key=SECRET,
        algorithm="HS256",
        expires_delta=timedelta(minutes=5),
    )
    with pytest.raises(AuthenticationError):
        decode_token(token, "refresh", secret_key=SECRET, algorithm="HS256")


def test_video_playback_token_is_scoped_and_not_an_access_token() -> None:
    token = create_video_playback_token(7, 11, 13)
    payload = decode_token(token, "video_playback")
    assert payload["sub"] == "7"
    assert payload["church_id"] == 11
    assert payload["video_id"] == 13
    assert payload["purpose"] == "video_playback"
    assert payload["nonce"]
    with pytest.raises(AuthenticationError):
        decode_token(token, "access")


def test_expired_video_playback_token_is_rejected() -> None:
    token = create_video_playback_token(
        7, 11, 13, expires_delta=timedelta(seconds=1), now=datetime.now(UTC) - timedelta(minutes=1)
    )
    with pytest.raises(AuthenticationError):
        decode_token(token, "video_playback")
