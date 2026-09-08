from dataclasses import dataclass
from urllib.parse import parse_qs, urlparse

from app.core.exceptions import RequestValidationError

_HOSTS = {"youtube.com", "www.youtube.com", "m.youtube.com", "youtu.be"}

@dataclass(frozen=True)
class YouTubeSource:
    video_id: str
    thumbnail_ref: str

def parse_youtube_url(value: str) -> YouTubeSource:
    parsed = urlparse(value.strip())
    host = (parsed.hostname or "").lower()
    if parsed.scheme not in {"http", "https"} or host not in _HOSTS:
        raise RequestValidationError("A valid YouTube URL is required")
    path = [segment for segment in parsed.path.split("/") if segment]
    video_id: str | None = None
    if host == "youtu.be":
        video_id = path[0] if path else None
    elif path[:1] == ["watch"]:
        video_id = parse_qs(parsed.query).get("v", [None])[0]
    elif len(path) >= 2 and path[0] in {"live", "shorts", "embed"}:
        video_id = path[1]
    if not video_id or not video_id.replace("-", "").replace("_", "").isalnum() or len(video_id) > 64:
        raise RequestValidationError("A valid YouTube video identifier is required")
    return YouTubeSource(video_id=video_id, thumbnail_ref=f"https://i.ytimg.com/vi/{video_id}/hqdefault.jpg")
