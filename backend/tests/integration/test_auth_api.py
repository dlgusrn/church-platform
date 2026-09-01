from collections.abc import Iterator
from uuid import uuid4

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.main import app
from app.models.refresh_token import RefreshToken
from app.models.user import User

pytestmark = pytest.mark.integration


@pytest.fixture
def client(mysql_session: Session) -> Iterator[TestClient]:
    def override_database() -> Iterator[Session]:
        yield mysql_session

    app.dependency_overrides[get_db] = override_database
    with TestClient(app) as test_client:
        yield test_client
    app.dependency_overrides.clear()


def test_register_variants_and_validation(client: TestClient, mysql_session: Session) -> None:
    suffix = uuid4().hex
    password = "strong-password-123"
    payloads = [
        {
            "name": "Email User",
            "email": f"email-{suffix}@example.com",
            "password": password,
        },
        {
            "name": "Phone User",
            "phone": f"010{uuid4().int % 100000000:08d}",
            "password": password,
        },
        {
            "name": "Both User",
            "email": f"both-{suffix}@example.com",
            "phone": f"010{uuid4().int % 100000000:08d}",
            "password": password,
        },
    ]

    for payload in payloads:
        response = client.post("/api/v1/auth/register", json=payload)
        assert response.status_code == 201, response.text
        user = mysql_session.scalar(select(User).where(User.id == response.json()["id"]))
        assert user is not None
        assert user.password_hash != password
        assert user.password_hash.startswith("$argon2")

    invalid = client.post(
        "/api/v1/auth/register",
        json={"name": "No Identifier", "password": password},
    )
    assert invalid.status_code == 422


@pytest.mark.parametrize("duplicate_field", ["email", "phone"])
def test_register_duplicate_identifier_returns_conflict(
    client: TestClient,
    duplicate_field: str,
) -> None:
    suffix = uuid4().hex
    value = (
        f"duplicate-{suffix}@example.com"
        if duplicate_field == "email"
        else f"010{uuid4().int % 100000000:08d}"
    )
    payload = {
        "name": "Original",
        duplicate_field: value,
        "password": "strong-password-123",
    }

    assert client.post("/api/v1/auth/register", json=payload).status_code == 201
    duplicate = client.post("/api/v1/auth/register", json=payload | {"name": "Duplicate"})

    assert duplicate.status_code == 409


def test_login_me_and_refresh_rotation(client: TestClient, mysql_session: Session) -> None:
    suffix = uuid4().hex
    email = f"login-{suffix}@example.com"
    phone = f"010{uuid4().int % 100000000:08d}"
    password = "strong-password-123"
    register = client.post(
        "/api/v1/auth/register",
        json={"name": "Login User", "email": email, "phone": phone, "password": password},
    )
    assert register.status_code == 201, register.text

    email_login = client.post(
        "/api/v1/auth/login",
        json={"identifier": email.upper(), "password": password},
    )
    assert email_login.status_code == 200, email_login.text
    phone_login = client.post(
        "/api/v1/auth/login",
        json={"identifier": phone, "password": password},
    )
    assert phone_login.status_code == 200, phone_login.text

    assert client.post(
        "/api/v1/auth/login",
        json={"identifier": email, "password": "wrong-password"},
    ).status_code == 401
    missing = client.post(
        "/api/v1/auth/login",
        json={"identifier": f"missing-{suffix}@example.com", "password": password},
    )
    assert missing.status_code == 401
    assert missing.json()["detail"] == "Invalid credentials"

    tokens = email_login.json()
    me = client.get(
        "/api/v1/users/me",
        headers={"Authorization": f"Bearer {tokens['access_token']}"},
    )
    assert me.status_code == 200
    assert me.json()["email"] == email

    rotated = client.post(
        "/api/v1/auth/refresh",
        json={"refresh_token": tokens["refresh_token"]},
    )
    assert rotated.status_code == 200, rotated.text
    assert rotated.json()["refresh_token"] != tokens["refresh_token"]
    assert client.post(
        "/api/v1/auth/refresh",
        json={"refresh_token": tokens["refresh_token"]},
    ).status_code == 401

    stored_tokens = mysql_session.scalars(select(RefreshToken)).all()
    assert stored_tokens
    assert all(token.token_hash != tokens["refresh_token"] for token in stored_tokens)
    assert any(token.revoked_at is not None for token in stored_tokens)


def test_health_and_openapi(client: TestClient) -> None:
    assert client.get("/api/v1/health").json() == {"status": "ok"}
    assert client.get("/api/v1/health/database").json() == {
        "status": "ok",
        "database": "ok",
    }

    schema = client.get("/openapi.json")
    assert schema.status_code == 200
    paths = schema.json()["paths"]
    assert {
        "/api/v1/health",
        "/api/v1/health/database",
        "/api/v1/auth/register",
        "/api/v1/auth/login",
        "/api/v1/auth/refresh",
        "/api/v1/users/me",
    } <= set(paths)
