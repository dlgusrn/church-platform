from dataclasses import dataclass, field
from datetime import UTC, datetime
from pathlib import PurePosixPath
import re

VIDEO_EXTENSIONS = {".mp4", ".mov", ".m4v"}

@dataclass(frozen=True)
class FolderInferenceRule:
    token: str
    category: str | None = None
    confidence: str = "medium"

DEFAULT_FOLDER_RULES = (
    FolderInferenceRule("설교", "예배"),
    FolderInferenceRule("행사", "행사"),
    FolderInferenceRule("선교", "해외선교"),
)

@dataclass(frozen=True)
class SynologyVideoCandidate:
    source_ref: str
    relative_path: str
    filename: str
    file_size: int
    inferred_title: str
    inferred_recorded_at: datetime | None
    category_suggestion: str | None
    collection_suggestion: str | None
    warnings: tuple[str, ...] = field(default_factory=tuple)

def is_video_path(path: str) -> bool:
    name = PurePosixPath(path).name
    return not name.startswith(".") and name.lower() not in {"thumbs.db", ".ds_store"} and PurePosixPath(name).suffix.lower() in VIDEO_EXTENSIONS

def infer_candidate(relative_path: str, *, file_size: int = 0, rules: tuple[FolderInferenceRule, ...] = DEFAULT_FOLDER_RULES) -> SynologyVideoCandidate:
    path = PurePosixPath(relative_path)
    if path.is_absolute() or ".." in path.parts or not is_video_path(relative_path):
        raise ValueError("invalid video path")
    parts = path.parts
    stem = path.stem
    # Discovery above deliberately ignores folder taxonomy. Rules only suggest app metadata.
    category = next((rule.category for rule in rules if any(rule.token in part for part in parts)), None)
    match = re.match(r"(?:(\d{8})|(\d{6}))", stem)
    date = None; warnings: list[str] = []
    if match:
        raw = match.group(1) or match.group(2)
        try: date = datetime.strptime(raw, "%Y%m%d" if len(raw) == 8 else "%y%m%d").replace(tzinfo=UTC)
        except ValueError: warnings.append("filename date is invalid")
    suffix = stem[match.end():] if match else stem
    worship = "낮예배" if "낮" in suffix else "밤예배" if "밤" in suffix else "송구영신예배" if "송구영신" in suffix else None
    title = f"{date.year:04d}년 {date.month:02d}월 {date.day:02d}일 {worship}" if date and worship else stem
    folders = [p for p in parts[:-1] if not re.fullmatch(r"\d{2,4}년?|\d{1,2}", p)]
    # A generic nested folder is only a low-confidence suggestion for event/mission;
    # unknown trees remain unresolved rather than becoming app taxonomy.
    collection = folders[-1] if category in {"행사", "해외선교"} and folders and not re.fullmatch(r"\d{2,4}년?|\d{1,2}", folders[-1]) else None
    normalized = path.as_posix()
    return SynologyVideoCandidate(normalized, normalized, path.name, file_size, title, date, category, collection, tuple(warnings))
