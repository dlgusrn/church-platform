import pytest
from pydantic import ValidationError

from app.schemas.notice import NoticeCreateRequest, NoticeUpdateRequest


@pytest.mark.parametrize("field", ["title", "content"])
def test_notice_create_rejects_blank_required_text(field: str) -> None:
    values = {"title": "공지", "content": "내용"}
    values[field] = " \n\t "

    with pytest.raises(ValidationError, match="must not be blank"):
        NoticeCreateRequest(**values)


@pytest.mark.parametrize("field", ["title", "content"])
def test_notice_update_rejects_blank_or_null_text(field: str) -> None:
    with pytest.raises(ValidationError):
        NoticeUpdateRequest(**{field: "   "})
    with pytest.raises(ValidationError, match=f"{field} cannot be null"):
        NoticeUpdateRequest(**{field: None})
