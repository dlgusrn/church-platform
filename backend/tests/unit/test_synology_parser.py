import pytest

from app.services.video_sources.synology.parser import infer_candidate, is_video_path, normalize_title


@pytest.mark.parametrize("path", ["주일예배/a.mp4", "청년부/a.mov", "foo/bar/baz/a.m4v", "2027여름수련회/a.mp4"])
def test_discovery_is_independent_of_folder_names(path: str) -> None:
    assert is_video_path(path)
    assert infer_candidate(path).source_ref == path


def test_folder_names_do_not_create_category_or_collection() -> None:
    item = infer_candidate("event-like/2026/01/20260104-message.mp4")
    assert item.category_suggestion is None
    assert item.collection_suggestion is None


@pytest.mark.parametrize("name", ["x/20260104-message.mp4", "x/message-20260104.mp4", "x/260104-message.mp4"])
def test_observed_filename_date_patterns_are_parsed(name: str) -> None:
    item = infer_candidate(name)
    assert item.inferred_recorded_at is not None
    assert "missing_recorded_at" not in item.review_reasons


def test_invalid_or_unknown_date_is_not_guessed() -> None:
    item = infer_candidate("x/20261340-message.mp4")
    assert item.inferred_recorded_at is None
    assert "missing_recorded_at" in item.review_reasons


def test_title_normalization_is_conservative() -> None:
    item = infer_candidate("x/20260104-message-final-1080p.mp4")
    assert item.inferred_title == "message"
    assert "ambiguous_title" not in item.review_reasons


def test_empty_normalization_falls_back_to_original_stem() -> None:
    title, fallback = normalize_title("20260104")
    assert title == "20260104"
    assert fallback is True
    assert "ambiguous_title" in infer_candidate("x/20260104.mp4").review_reasons


@pytest.mark.parametrize("path", ["a.txt", "a.sfk", ".hidden.mp4", "../escape.mp4", "/outside.mp4"])
def test_ignore_and_confinement(path: str) -> None:
    if path in {"../escape.mp4", "/outside.mp4"}:
        with pytest.raises(ValueError):
            infer_candidate(path)
    else:
        assert not is_video_path(path)
