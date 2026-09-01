from typing import Self

from pydantic import BaseModel, EmailStr, Field, field_validator, model_validator


class RegisterRequest(BaseModel):
    name: str = Field(min_length=1, max_length=100)
    email: EmailStr | None = None
    phone: str | None = Field(default=None, min_length=8, max_length=32)
    password: str = Field(min_length=8, max_length=128)

    @field_validator("name")
    @classmethod
    def reject_blank_name(cls, value: str) -> str:
        if not value.strip():
            raise ValueError("name must not be blank")
        return value

    @field_validator("phone")
    @classmethod
    def validate_phone_digits(cls, value: str | None) -> str | None:
        if value is None:
            return None
        digit_count = sum(character.isdigit() for character in value)
        if digit_count < 8:
            raise ValueError("phone must contain at least 8 digits")
        return value

    @model_validator(mode="after")
    def require_email_or_phone(self) -> Self:
        if self.email is None and not (self.phone and self.phone.strip()):
            raise ValueError("email or phone is required")
        return self


class LoginRequest(BaseModel):
    identifier: str = Field(min_length=1, max_length=320)
    password: str = Field(min_length=1, max_length=128)


class RefreshTokenRequest(BaseModel):
    refresh_token: str = Field(min_length=1)


class TokenResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
