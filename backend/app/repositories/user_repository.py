from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models.user import User


class UserRepository:
    def __init__(self, session: Session) -> None:
        self.session = session

    def get_by_id(self, user_id: int) -> User | None:
        return self.session.get(User, user_id)

    def get_by_email(self, email: str) -> User | None:
        return self.session.scalar(select(User).where(User.email == email))

    def get_by_phone(self, phone: str) -> User | None:
        return self.session.scalar(select(User).where(User.phone == phone))

    def add(self, user: User) -> User:
        self.session.add(user)
        self.session.flush()
        return user
