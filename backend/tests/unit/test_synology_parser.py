import pytest

from app.services.video_sources.synology.parser import infer_candidate, is_video_path

@pytest.mark.parametrize("path", ["주일예배/a.mp4", "청년부/a.mov", "foo/bar/baz/a.m4v", "2027여름수련회/a.mp4"])
def test_discovery_is_independent_of_folder_names(path: str) -> None:
    assert is_video_path(path)
    assert infer_candidate(path).source_ref == path

def test_unknown_folder_remains_unresolved() -> None:
    item = infer_candidate("아무이름/테스트.mp4")
    assert item.category_suggestion is None
    assert item.collection_suggestion is None

def test_known_folder_is_only_a_heuristic() -> None:
    assert infer_candidate("2.행사/성탄절/01.mp4").category_suggestion == "행사"

@pytest.mark.parametrize("name,expected", [("새폴더/260104낮w.mp4", "낮예배"), ("x/260104밤.mp4", "밤예배"), ("x/20260101송구영신.mp4", "송구영신예배")])
def test_filename_inference_is_folder_independent(name: str, expected: str) -> None:
    assert expected in infer_candidate(name).inferred_title

@pytest.mark.parametrize("path", ["a.txt", "a.sfk", ".hidden.mp4", "../escape.mp4", "/outside.mp4"])
def test_ignore_and_confinement(path: str) -> None:
    if path in {"../escape.mp4", "/outside.mp4"}:
        with pytest.raises(ValueError): infer_candidate(path)
    else: assert not is_video_path(path)
