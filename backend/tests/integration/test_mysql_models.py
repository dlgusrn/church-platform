from datetime import UTC, datetime
from uuid import uuid4

import pytest
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.models.church import Church
from app.models.membership import ChurchMembership
from app.models.user import User

pytestmark = pytest.mark.integration


def _user(*, email: str | None = None, phone: str | None = None) -> User:
    return User(
        name="Nullable Identifier User",
        email=email,
        phone=phone,
        password_hash="not-a-plaintext-password",
    )


def test_email_and_phone_are_independently_nullable(mysql_session: Session) -> None:
    suffix = uuid4().hex
    email_only = _user(email=f"email-only-{suffix}@example.com")
    phone_only = _user(phone=f"010{uuid4().int % 100000000:08d}")
    mysql_session.add_all([email_only, phone_only])
    mysql_session.flush()

    assert email_only.phone is None
    assert phone_only.email is None


def test_duplicate_membership_is_rejected(mysql_session: Session) -> None:
    suffix = uuid4().hex
    user = _user(email=f"membership-{suffix}@example.com")
    church = Church(name="Integration Church", code=f"integration-{suffix}")
    mysql_session.add_all([user, church])
    mysql_session.flush()

    mysql_session.add_all(
        [
            ChurchMembership(
                user_id=user.id,
                church_id=church.id,
                requested_at=datetime.now(UTC),
            ),
            ChurchMembership(
                user_id=user.id,
                church_id=church.id,
                requested_at=datetime.now(UTC),
            ),
        ]
    )

    with pytest.raises(IntegrityError):
        mysql_session.flush()
