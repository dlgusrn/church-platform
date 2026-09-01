import pytest
from pydantic import ValidationError

from app.schemas.auth import RegisterRequest


def test_register_accepts_email() -> None:
    request = RegisterRequest(name="Email User", email="user@example.com", password="password123")
    assert str(request.email) == "user@example.com"
    assert request.phone is None


def test_register_accepts_phone() -> None:
    request = RegisterRequest(name="Phone User", phone="010-1234-5678", password="password123")
    assert request.email is None
    assert request.phone == "010-1234-5678"


def test_register_rejects_missing_email_and_phone() -> None:
    with pytest.raises(ValidationError):
        RegisterRequest(name="No Identifier", password="password123")


@pytest.mark.parametrize(
    ("name", "phone"),
    [
        ("   ", "010-1234-5678"),
        ("Invalid Phone", "----------"),
    ],
)
def test_register_rejects_blank_name_or_phone_without_enough_digits(
    name: str,
    phone: str,
) -> None:
    with pytest.raises(ValidationError):
        RegisterRequest(name=name, phone=phone, password="password123")
