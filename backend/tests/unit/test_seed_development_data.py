import pytest

from app.models.church import Church
from app.scripts.seed_development_data import reconcile_development_church


@pytest.mark.parametrize(
    ("legacy_code", "canonical_code", "name"),
    [
        ("skydoor", "skygate", "하늘문교회"),
        ("beersheba", "beer", "브엘성회"),
    ],
)
def test_reconcile_migrates_legacy_code_without_replacing_row(
    legacy_code: str,
    canonical_code: str,
    name: str,
) -> None:
    legacy = Church(id=7, code=legacy_code, name=name)

    church, created = reconcile_development_church(
        canonical=None,
        legacy=legacy,
        code=canonical_code,
        name=name,
    )

    assert church is legacy
    assert church.id == 7
    assert church.code == canonical_code
    assert church.is_active is True
    assert created is False


def test_reconcile_keeps_existing_canonical_church_idempotently() -> None:
    canonical = Church(id=8, code="beer", name="이전 이름", is_active=False)

    church, created = reconcile_development_church(
        canonical=canonical,
        legacy=None,
        code="beer",
        name="브엘성회",
    )

    assert church is canonical
    assert church.name == "브엘성회"
    assert church.is_active is True
    assert created is False


def test_reconcile_creates_only_canonical_code_when_missing() -> None:
    church, created = reconcile_development_church(
        canonical=None,
        legacy=None,
        code="skygate",
        name="하늘문교회",
    )

    assert church.code == "skygate"
    assert church.name == "하늘문교회"
    assert created is True


def test_reconcile_fails_safely_if_legacy_and_canonical_rows_both_exist() -> None:
    with pytest.raises(RuntimeError, match="reconcile them manually"):
        reconcile_development_church(
            canonical=Church(id=1, code="skygate", name="하늘문교회"),
            legacy=Church(id=2, code="skydoor", name="하늘문교회"),
            code="skygate",
            name="하늘문교회",
        )
