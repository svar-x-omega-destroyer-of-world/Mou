"""Unit tests for backend/app/explain.py (FR-11, Risk R-4).

The critical acceptance test: with no GEMINI_API_KEY set, the explain function
must return a full explanation with explanation_source == "fallback".
"""
from __future__ import annotations

from app.explain import explain
from app.fallbacks import get_fallback
from app.schemas import Confidence, ExplanationSource, Extracted, RootCause


class TestExplain:
    """explain() behaviour under various conditions."""

    def setup_method(self):
        self.extracted = Extracted(
            aadhaar_name="Rahima Begum",
            ration_name_script="রহিমা বেগম",
            ration_name_romanized="Rahima Begam",
            aadhaar_dob="1989-03-12",
            ration_dob="1989-03-12",
        )

    def test_fallback_when_no_api_key(self):
        """With no GEMINI_API_KEY, must return a fallback explanation (FR-11)."""
        text, source = explain(
            root_cause=RootCause.name_mismatch,
            confidence=Confidence.medium,
            extracted=self.extracted,
            symptom="turned_away_at_fps",
        )
        assert text, "Expected non-empty explanation"
        assert source == ExplanationSource.fallback, (
            f"Expected fallback source, got {source}"
        )
        # Should contain a root-cause-appropriate keyword
        assert "name" in text.lower() or "spelling" in text.lower(), (
            f"Expected name/spelling in fallback, got: {text[:100]}"
        )

    def test_fallback_for_each_root_cause(self):
        """Every root cause has a non-empty, unique fallback."""
        for rc in RootCause:
            text, source = explain(
                root_cause=rc,
                confidence=Confidence.low,
                extracted=self.extracted,
                symptom="other",
            )
            assert text, f"Empty fallback for {rc}"
            assert source == ExplanationSource.fallback
            # Fallback must not say "qualify"
            assert "qualify" not in text.lower(), (
                f"Fallback for {rc} uses 'qualify' (FR-10): {text[:100]}"
            )

    def test_get_fallback_directly(self):
        """Fallback helper returns correct strings."""
        text = get_fallback(RootCause.name_mismatch)
        assert "name" in text.lower()
        assert "likely cause" in text.lower()

        text = get_fallback(RootCause.biometric_failure)
        assert "fingerprint" in text.lower() or "biometric" in text.lower()

        text = get_fallback(RootCause.unknown)
        assert "could not identify" in text.lower()

    def test_fallback_never_mentions_eligibility(self):
        """FR-10: no fallback mentions eligibility."""
        for rc in RootCause:
            text = get_fallback(rc.value)
            assert "not eligible" not in text.lower(), (
                f"{rc} fallback uses 'not eligible': {text[:80]}"
            )
