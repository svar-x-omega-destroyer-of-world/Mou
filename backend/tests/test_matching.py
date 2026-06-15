"""Unit tests for backend/app/matching.py (rules_spec.md §3 table)."""
from __future__ import annotations

from app.matching import name_score, dob_status, romanise, normalise


# ---------------------------------------------------------------------------
# §3 Name matching — expected bands
# ---------------------------------------------------------------------------

class TestNameScore:
    """rules_spec.md §3 expected-outputs table."""

    def test_begum_begam_is_70_84(self):
        """The flagship case: Rahima Begum vs রহিমা বেগম → 70–84 band."""
        score = name_score("Rahima Begum", "রহিমা বেগম")
        assert 70 <= score <= 84, f"Expected 70–84, got {score}"

    def test_begum_begum_is_ge85(self):
        """Same spelling → normalised identical → ≥85."""
        # "Same spelling" = the ration card Bengali romanises to the
        # same Latin form WITHOUT the inherent-a offset.
        # Here the Bengali explicitly writes "রহিমা বেগুম" (long-u vowel)
        # which ITRANS romanises to the same normalised form.
        score = name_score("Rahima Begum", "রহিমা বেগুম")
        assert score >= 85, f"Expected ≥85, got {score}"

    def test_anil_kumar_is_ge85(self):
        """Anil Kumar vs অনিল কুমার → ≥85."""
        score = name_score("Anil Kumar", "অনিল কুমার")
        assert score >= 85, f"Expected ≥85, got {score}"

    def test_fatima_khatun_is_ge85(self):
        """Fatima Khatun vs ফাতিমা খাতুন → ≥85."""
        score = name_score("Fatima Khatun", "ফাতিমা খাতুন")
        assert score >= 85, f"Expected ≥85, got {score}"


# ---------------------------------------------------------------------------
# §3 romanise — unit smoke-test
# ---------------------------------------------------------------------------

class TestRomanise:
    def test_rahima_begum(self):
        r = romanise("রহিমা বেগম")
        assert "rahim" in r, f"Expected ITRANS with 'rahim', got {r!r}"
        assert "vegam" in r or "begam" in r, f"Expected 'vegam' or 'begam', got {r!r}"

    def test_anil_kumar(self):
        r = romanise("অনিল কুমার")
        assert r, f"Expected non-empty, got {r!r}"


# ---------------------------------------------------------------------------
# §3 normalise — behaviour verification
# ---------------------------------------------------------------------------

class TestNormalise:
    def test_drop_trailing_a(self):
        """drop_trailing_a=True removes final 'a' from tokens."""
        assert normalise("rahima begama", drop_trailing_a=True) == "rahim begam"

    def test_keep_trailing_a(self):
        """drop_trailing_a=False leaves final 'a' in place."""
        assert normalise("rahima begama", drop_trailing_a=False) == "rahima begama"

    def test_clean_punctuation(self):
        assert normalise("Rahima, Begum!", drop_trailing_a=True) == "rahim begum"

    def test_collapse_whitespace(self):
        assert normalise("  Rahima   Begum  ", drop_trailing_a=True) == "rahim begum"

    def test_itrans_mappings(self):
        """v→b, ph→f, kh→k, A→a."""
        assert normalise("rahimA vegama", drop_trailing_a=False) == "rahima begama"
        assert normalise("phAtimA khAtuna", drop_trailing_a=False) == "fatima katuna"


# ---------------------------------------------------------------------------
# §3 dob_status — unit tests
# ---------------------------------------------------------------------------

class TestDobStatus:
    def test_match(self):
        assert dob_status("1989-03-12", "1989-03-12") == "match"

    def test_match_with_different_separators(self):
        assert dob_status("1989-03-12", "1989/03/12") == "match"

    def test_mismatch(self):
        assert dob_status("1989-03-12", "1990-06-01") == "mismatch"

    def test_unknown_when_none(self):
        assert dob_status(None, "1989-03-12") == "unknown"
        assert dob_status("1989-03-12", None) == "unknown"
        assert dob_status(None, None) == "unknown"
