from dataclasses import dataclass
from datetime import UTC, datetime
from uuid import uuid4

from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.core.config import get_settings
from app.core.exceptions import RequestValidationError
from app.models.video import Video, VideoSourceType
from app.repositories.video_repository import VideoRepository
from app.services.video_sources.synology.client import SynologyError, SynologyFileStationClient
from app.services.video_sources.synology.parser import SynologyVideoCandidate, infer_candidate, is_video_path

@dataclass
class Snapshot:
    church_id: int
    candidates: dict[str, SynologyVideoCandidate]

_snapshots: dict[str, Snapshot] = {}

class SynologyImportService:
    def __init__(self, session: Session, client_factory=SynologyFileStationClient) -> None:
        self.session, self.videos, self.client_factory = session, VideoRepository(session), client_factory

    def configured(self) -> bool:
        s = get_settings()
        return bool(s.synology_base_url and s.synology_username and s.synology_password and s.synology_video_root)

    def connection_test(self) -> dict[str, bool]:
        if not self.configured(): return {"configured": False, "reachable": False, "authenticated": False, "root_accessible": False}
        try:
            with self._client() as client: client.list_directory(self._root(), limit=1)
            return {"configured": True, "reachable": True, "authenticated": True, "root_accessible": True}
        except SynologyError:
            return {"configured": True, "reachable": False, "authenticated": False, "root_accessible": False}

    def preview(self, church_id: int, *, offset: int, limit: int) -> tuple[str, list[dict], dict]:
        if not self.configured(): raise RequestValidationError("Synology NAS is not configured")
        found = self._scan()
        categories = {x.name: x.id for x in self.videos.list_categories(church_id, active_only=True)}
        collections = {x.title: x.id for x in self.videos.list_collections(church_id)}
        rendered = []
        for c in found:
            duplicate = self.videos.get_by_source_for_church(church_id, VideoSourceType.SYNOLOGY, c.source_ref) is not None
            rendered.append({"source_ref": c.source_ref, "relative_path": c.relative_path, "filename": c.filename, "file_size": c.file_size, "inferred_title": c.inferred_title, "inferred_recorded_at": c.inferred_recorded_at, "category_suggestion": c.category_suggestion, "matched_category_id": categories.get(c.category_suggestion), "collection_suggestion": c.collection_suggestion, "matched_collection_id": collections.get(c.collection_suggestion), "duplicate": duplicate, "warnings": list(c.warnings)})
        token = uuid4().hex; _snapshots[token] = Snapshot(church_id, {c.source_ref: c for c in found})
        warning = sum(bool(x["warnings"]) for x in rendered)
        summary = {"total": len(rendered), "new": sum(not x["duplicate"] for x in rendered), "duplicate": sum(x["duplicate"] for x in rendered), "warning": warning}
        return token, rendered[offset:offset + limit], summary

    def import_candidates(self, church_id: int, token: str, refs: list[str]) -> dict[str, int]:
        snapshot = _snapshots.get(token)
        if snapshot is None or snapshot.church_id != church_id: raise RequestValidationError("Scan preview has expired")
        created = skipped = failed = 0
        categories = {x.name: x.id for x in self.videos.list_categories(church_id, active_only=True)}
        collections = {x.title: x.id for x in self.videos.list_collections(church_id)}
        for ref in dict.fromkeys(refs):
            candidate = snapshot.candidates.get(ref)
            if candidate is None: failed += 1; continue
            if self.videos.get_by_source_for_church(church_id, VideoSourceType.SYNOLOGY, ref): skipped += 1; continue
            try:
                video = Video(church_id=church_id, source_type=VideoSourceType.SYNOLOGY, source_ref=ref, title=candidate.inferred_title, recorded_at=candidate.inferred_recorded_at or datetime.now(UTC), category_id=categories.get(candidate.category_suggestion), collection_id=collections.get(candidate.collection_suggestion), is_published=False)
                self.videos.add_video(video); self.session.commit(); created += 1
            except IntegrityError:
                self.session.rollback(); skipped += 1
            except Exception:
                self.session.rollback(); failed += 1
        return {"created": created, "skipped": skipped, "failed": failed}

    def _client(self):
        s = get_settings(); return self.client_factory(s.synology_base_url or "", s.synology_username or "", s.synology_password or "")
    def _root(self) -> str:
        root = get_settings().synology_video_root or ""
        if not root.startswith("/") or ".." in root.split("/"): raise RequestValidationError("Synology video root is invalid")
        return root.rstrip("/") or "/"
    def _scan(self) -> list[SynologyVideoCandidate]:
        root = self._root(); queue = [root]; output: list[SynologyVideoCandidate] = []
        with self._client() as client:
            while queue:
                folder = queue.pop(0); offset = 0
                while True:
                    entries, total = client.list_directory(folder, offset=offset)
                    for entry in entries:
                        if not self._within_root(entry.path, root): continue
                        rel = entry.path[len(root):].lstrip("/")
                        if entry.is_dir:
                            if entry.name and not entry.name.startswith("."): queue.append(entry.path)
                        elif is_video_path(rel): output.append(infer_candidate(rel, file_size=entry.size))
                    offset += len(entries)
                    if not entries or offset >= total: break
        return output
    @staticmethod
    def _within_root(path: str, root: str) -> bool:
        parts = path.split("/")
        return ".." not in parts and (path == root or path.startswith(root.rstrip("/") + "/"))
