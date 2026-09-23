from dataclasses import dataclass, field
from datetime import UTC, datetime
from pathlib import PurePosixPath
import re

VIDEO_EXTENSIONS = {".mp4", ".mov", ".m4v"}

# These are intentionally narrow. They cover date forms observed during the
# NAS inventory and do not try to derive dates from arbitrary digits.
_DATE_VALUE = r"(?:(?:19|20)\d{2}(?:0[1-9]|1[0-2])(?:0[1-9]|[12]\d|3[01])|\d{6})"
DATE_PREFIX_RE = re.compile(rf"^(?P<date>{_DATE_VALUE})(?:[ _.-]+|(?=[^0-9])|$)")
DATE_SUFFIX_RE = re.compile(rf"(?:[ _.-]+)(?P<date>{_DATE_VALUE})$")
_KNOWN_SUFFIX_RE = re.compile(
    r"(?:[ _.-]+)(?:copy|edit|edited|final|encode(?:d)?|h[ ._-]?26[45]|hevc|avc|"
    r"1080p|720p|4k|fhd|uhd)(?:[ _.-]*\d+)?$",
    re.IGNORECASE,
)
_YEAR_RE = re.compile(r"(?:19|20)\d{2}(?:년)?$")
_MONTH_RE = re.compile(r"(?:0?[1-9]|1[0-2])(?:월)?$")


@dataclass(frozen=True)
class FolderInferenceRule:
    """Retained as a compatibility type; bulk import does not infer taxonomy."""

    token: str
    category: str | None = None
    confidence: str = "medium"


DEFAULT_FOLDER_RULES: tuple[FolderInferenceRule, ...] = ()


@dataclass(frozen=True)
class SynologyVideoCandidate:
    source_ref: str
    relative_path: str
    filename: str
    file_size: int
    extension: str
    inferred_title: str
    inferred_recorded_at: datetime | None
    category_suggestion: str | None = None
    collection_suggestion: str | None = None
    warnings: tuple[str, ...] = field(default_factory=tuple)
    review_reasons: tuple[str, ...] = field(default_factory=tuple)


def is_video_path(path: str) -> bool:
    name = PurePosixPath(path).name
    return (
        not name.startswith(".")
        and name.lower() not in {"thumbs.db", ".ds_store"}
        and PurePosixPath(name).suffix.lower() in VIDEO_EXTENSIONS
    )


def _parse_date(value: str) -> datetime | None:
    try:
        return datetime.strptime(value, "%Y%m%d" if len(value) == 8 else "%y%m%d").replace(tzinfo=UTC)
    except ValueError:
        return None


def normalize_title(stem: str) -> tuple[str, bool]:
    """Return a conservatively cleaned title and whether fallback was required."""
    value = stem.strip()
    prefix = DATE_PREFIX_RE.match(value)
    if prefix:
        value = value[prefix.end():]
    value = DATE_SUFFIX_RE.sub("", value)
    while True:
        cleaned = _KNOWN_SUFFIX_RE.sub("", value)
        if cleaned == value:
            break
        value = cleaned
    value = value.strip(" _.-")
    if not value:
        return stem, True
    return value, False


def infer_candidate(
    relative_path: str,
    *,
    file_size: int = 0,
    rules: tuple[FolderInferenceRule, ...] = DEFAULT_FOLDER_RULES,
) -> SynologyVideoCandidate:
    del rules  # Folder names do not create application taxonomy.
    path = PurePosixPath(relative_path)
    if path.is_absolute() or ".." in path.parts or not is_video_path(relative_path):
        raise ValueError("invalid video path")

    stem = path.stem
    date_match = DATE_PREFIX_RE.match(stem) or DATE_SUFFIX_RE.search(stem)
    recorded_at = _parse_date(date_match.group("date")) if date_match else None
    title, used_fallback = normalize_title(stem)

    reasons: list[str] = []
    if recorded_at is None:
        reasons.append("missing_recorded_at")
        directories = path.parts[:-1]
        has_year_month = any(_YEAR_RE.fullmatch(part) for part in directories) and any(
            _MONTH_RE.fullmatch(part) for part in directories
        )
        if not has_year_month:
            reasons.append("unknown_structure")
    if used_fallback:
        reasons.append("ambiguous_title")

    normalized = path.as_posix()
    return SynologyVideoCandidate(
        source_ref=normalized,
        relative_path=normalized,
        filename=path.name,
        file_size=file_size,
        extension=path.suffix.lower().lstrip("."),
        inferred_title=title,
        inferred_recorded_at=recorded_at,
        category_suggestion=None,
        collection_suggestion=None,
        warnings=tuple(reasons),
        review_reasons=tuple(reasons),
    )
