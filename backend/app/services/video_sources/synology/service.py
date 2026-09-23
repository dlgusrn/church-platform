from dataclasses import dataclass
from uuid import uuid4

from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.core.config import get_settings
from app.core.exceptions import RequestValidationError
from app.models.video import Video, VideoSourceType
from app.repositories.video_repository import VideoRepository
from app.services.video_sources.synology.client import SynologyError, SynologyFileStationClient
from app.services.video_sources.synology.parser import SynologyVideoCandidate, infer_candidate, is_video_path

DEFAULT_BATCH_SIZE = 100
MAX_BATCH_SIZE = 200
_STATUS_FILTERS = {"all", "new", "already_imported", "needs_review", "ready", "duplicate"}


@dataclass
class Snapshot:
    church_id: int
    candidates: tuple[SynologyVideoCandidate, ...]


_snapshots: dict[str, Snapshot] = {}


class SynologyImportService:
    def __init__(self, session: Session, client_factory=SynologyFileStationClient) -> None:
        self.session, self.videos, self.client_factory = session, VideoRepository(session), client_factory

    def configured(self) -> bool:
        settings = get_settings()
        return bool(settings.synology_base_url and settings.synology_username and settings.synology_password and settings.synology_video_root)

    def connection_test(self) -> dict[str, bool]:
        if not self.configured():
            return {"configured": False, "reachable": False, "authenticated": False, "root_accessible": False}
        try:
            with self._client() as client:
                client.list_directory(self._root(), limit=1)
            return {"configured": True, "reachable": True, "authenticated": True, "root_accessible": True}
        except SynologyError:
            return {"configured": True, "reachable": False, "authenticated": False, "root_accessible": False}

    def preview(self, church_id: int, *, offset: int, limit: int = DEFAULT_BATCH_SIZE, snapshot_token: str | None = None, status_filter: str = "all", folder: str | None = None) -> tuple[str, list[dict], dict, list[str], list[str]]:
        if not self.configured():
            raise RequestValidationError("Synology NAS is not configured")
        if status_filter not in _STATUS_FILTERS:
            raise RequestValidationError("Synology preview status filter is invalid")
        if limit > MAX_BATCH_SIZE:
            raise RequestValidationError("Synology preview limit exceeds maximum")
        normalized_folder = self._normalize_folder(folder)
        snapshot_token, found = self._load_snapshot(church_id, snapshot_token)
        rendered = self._render_candidates(church_id, found)
        filtered = [item for item in rendered if self._matches_filter(item, status_filter=status_filter, folder=normalized_folder)]
        # Aggregate counts deliberately describe the full snapshot, not the
        # current page or filter. The administrator must never see a guessed
        # library total after changing a filter.
        summary = {
            "total": len(rendered), "filtered_total": len(filtered),
            "new": sum(not item["already_imported"] for item in rendered),
            "already_imported": sum(item["already_imported"] for item in rendered),
            "needs_review": sum(item["needs_review"] for item in rendered),
            "ready": sum(not item["already_imported"] and not item["needs_review"] for item in rendered),
            "duplicate": sum(item["already_imported"] for item in rendered),
            "warning": sum(item["needs_review"] for item in rendered),
        }
        return snapshot_token, filtered[offset:offset + limit], summary, self._folder_facets(found), [item["source_ref"] for item in filtered if not item["already_imported"]]

    def import_candidates(self, church_id: int, token: str, refs: list[str]) -> dict:
        if len(refs) > MAX_BATCH_SIZE:
            raise RequestValidationError("Synology import batch exceeds maximum")
        _, candidates = self._load_snapshot(church_id, token)
        by_ref = {candidate.source_ref: candidate for candidate in candidates}
        rendered = {item["source_ref"]: item for item in self._render_candidates(church_id, candidates)}
        results: list[dict] = []
        imported = already_imported = failed = needs_review = 0
        for ref in dict.fromkeys(refs):
            candidate = by_ref.get(ref)
            if candidate is None:
                failed += 1; results.append({"status": "failed", "video_id": None, "error_code": "candidate_not_in_snapshot"}); continue
            item = rendered[ref]
            if item["already_imported"]:
                already_imported += 1; results.append({"status": "already_imported", "video_id": None, "error_code": None}); continue
            # The schema requires recorded_at; no synthetic date is permitted.
            if "missing_recorded_at" in item["review_reasons"]:
                needs_review += 1; results.append({"status": "needs_review", "video_id": None, "error_code": "missing_recorded_at"}); continue
            try:
                video = Video(church_id=church_id, source_type=VideoSourceType.SYNOLOGY, source_ref=ref, title=candidate.inferred_title, recorded_at=candidate.inferred_recorded_at, category_id=None, collection_id=None, is_published=False)
                self.videos.add_video(video)
                self.session.commit()
                imported += 1; results.append({"status": "imported", "video_id": video.id, "error_code": None})
            except IntegrityError:
                self.session.rollback()
                already_imported += 1; results.append({"status": "already_imported", "video_id": None, "error_code": None})
            except Exception:
                self.session.rollback()
                failed += 1; results.append({"status": "failed", "video_id": None, "error_code": "import_failed"})
        return {"requested_count": len(refs), "imported_count": imported, "already_imported_count": already_imported, "failed_count": failed, "needs_review_count": needs_review, "items": results, "created": imported, "skipped": already_imported, "failed": failed}

    def _load_snapshot(self, church_id: int, token: str | None) -> tuple[str, tuple[SynologyVideoCandidate, ...]]:
        if token is None:
            found = tuple(self._scan()); token = uuid4().hex; _snapshots[token] = Snapshot(church_id, found)
            return token, found
        snapshot = _snapshots.get(token)
        if snapshot is None:
            raise RequestValidationError("snapshot_not_found")
        if snapshot.church_id != church_id:
            raise RequestValidationError("snapshot_expired_or_process_restarted")
        return token, snapshot.candidates

    def _render_candidates(self, church_id: int, candidates: tuple[SynologyVideoCandidate, ...]) -> list[dict]:
        imported_refs = {candidate.source_ref for candidate in candidates if self.videos.get_by_source_for_church(church_id, VideoSourceType.SYNOLOGY, candidate.source_ref) is not None}
        possible_duplicate_refs = self._possible_duplicate_refs(candidates)
        rendered: list[dict] = []
        for candidate in candidates:
            reasons = list(candidate.review_reasons or candidate.warnings)
            if candidate.source_ref in possible_duplicate_refs and "possible_duplicate" not in reasons:
                reasons.append("possible_duplicate")
            already_imported = candidate.source_ref in imported_refs
            rendered.append({"source_ref": candidate.source_ref, "relative_path": candidate.relative_path, "filename": candidate.filename, "file_size": candidate.file_size, "extension": candidate.extension, "inferred_title": candidate.inferred_title, "inferred_recorded_at": candidate.inferred_recorded_at, "category_suggestion": None, "matched_category_id": None, "collection_suggestion": None, "matched_collection_id": None, "duplicate": already_imported, "already_imported": already_imported, "warnings": reasons, "needs_review": bool(reasons), "review_reasons": reasons})
        return rendered

    @staticmethod
    def _possible_duplicate_refs(candidates: tuple[SynologyVideoCandidate, ...]) -> set[str]:
        groups: dict[tuple[str, object, int], list[str]] = {}
        for candidate in candidates:
            if candidate.inferred_recorded_at is None or not candidate.inferred_title.strip() or candidate.file_size <= 0:
                continue
            groups.setdefault((candidate.inferred_title.casefold(), candidate.inferred_recorded_at.date(), candidate.file_size), []).append(candidate.source_ref)
        return {ref for refs in groups.values() if len(refs) > 1 for ref in refs}

    def _client(self):
        settings = get_settings()
        return self.client_factory(settings.synology_base_url or "", settings.synology_username or "", settings.synology_password or "", verify=settings.synology_tls_verify)

    def _root(self) -> str:
        root = get_settings().synology_video_root or ""
        if not root.startswith("/") or ".." in root.split("/"):
            raise RequestValidationError("Synology video root is invalid")
        return root.rstrip("/") or "/"

    @staticmethod
    def _normalize_folder(folder: str | None) -> str | None:
        if folder is None or not folder.strip(): return None
        normalized = folder.strip().strip("/")
        if not normalized or ".." in normalized.split("/"):
            raise RequestValidationError("Synology preview folder is invalid")
        return normalized

    @staticmethod
    def _folder_facets(candidates: tuple[SynologyVideoCandidate, ...]) -> list[str]:
        folders: set[str] = set()
        for candidate in candidates:
            parts = candidate.relative_path.split("/")[:-1]
            for index in range(1, len(parts) + 1): folders.add("/".join(parts[:index]))
        return sorted(folders)

    @staticmethod
    def _matches_filter(item: dict, *, status_filter: str, folder: str | None) -> bool:
        if folder is not None and not (item["relative_path"] == folder or item["relative_path"].startswith(f"{folder}/")): return False
        if status_filter == "all": return True
        if status_filter == "new": return not item["already_imported"]
        if status_filter in {"already_imported", "duplicate"}: return item["already_imported"]
        if status_filter == "needs_review": return item["needs_review"]
        return not item["already_imported"] and not item["needs_review"]

    def _scan(self) -> list[SynologyVideoCandidate]:
        root = self._root(); queue = [root]; output: list[SynologyVideoCandidate] = []
        with self._client() as client:
            while queue:
                folder = queue.pop(0); offset = 0
                while True:
                    entries, total = client.list_directory(folder, offset=offset)
                    for entry in entries:
                        if not self._within_root(entry.path, root): continue
                        relative = entry.path[len(root):].lstrip("/")
                        if entry.is_dir:
                            if entry.name and not entry.name.startswith("."): queue.append(entry.path)
                        elif is_video_path(relative): output.append(infer_candidate(relative, file_size=entry.size))
                    offset += len(entries)
                    if not entries or offset >= total: break
        return output

    @staticmethod
    def _within_root(path: str, root: str) -> bool:
        return ".." not in path.split("/") and (path == root or path.startswith(root.rstrip("/") + "/"))
