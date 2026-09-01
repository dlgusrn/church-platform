from uuid import uuid4

import pytest
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.models.user import User

pytestmark = pytest.mark.integration


def _user(*, email: str | None = None, phone: str | None = None) -> User:
    return User(
        name="Integration User",
        email=email,
        phone=phone,
        password_hash="not-a-plaintext-password",
    )


def test_duplicate_email_is_rejected(mysql_session: Session) -> None:
    email = f"duplicate-{uuid4().hex}@example.com"
    mysql_session.add_all([_user(email=email), _user(email=email)])

    with pytest.raises(IntegrityError):
        mysql_session.flush()


def test_duplicate_phone_is_rejected(mysql_session: Session) -> None:
    phone = f"010{uuid4().int % 100000000:08d}"
    mysql_session.add_all([_user(phone=phone), _user(phone=phone)])

    with pytest.raises(IntegrityError):
        mysql_session.flush()
