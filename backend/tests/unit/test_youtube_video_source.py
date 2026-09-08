import pytest

from app.core.exceptions import RequestValidationError
from app.services.video_sources.youtube import parse_youtube_url

@pytest.mark.parametrize("url,video_id", [
    ("https://www.youtube.com/watch?v=AbC_123-xyZ&t=2", "AbC_123-xyZ"),
    ("https://youtu.be/AbC_123-xyZ?feature=share", "AbC_123-xyZ"),
    ("https://www.youtube.com/live/AbC_123-xyZ", "AbC_123-xyZ"),
    ("https://www.youtube.com/shorts/AbC_123-xyZ", "AbC_123-xyZ"),
])
def test_parses_supported_youtube_urls(url: str, video_id: str) -> None:
    source = parse_youtube_url(url)
    assert source.video_id == video_id
    assert source.thumbnail_ref == f"https://i.ytimg.com/vi/{video_id}/hqdefault.jpg"

@pytest.mark.parametrize("url", ["https://youtube.com.evil.example/watch?v=abc", "https://example.com/watch?v=abc", "https://youtu.be/", "not-a-url"])
def test_rejects_invalid_youtube_urls(url: str) -> None:
    with pytest.raises(RequestValidationError):
        parse_youtube_url(url)
