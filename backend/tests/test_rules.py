"""Unit tests for backend/app/rules.py (rules_spec.md §2 worked-examples table).

Every row in the spec table must be represented here with a passing assertion.
"""
from __future__ import annotations

from app.rules import RuleInput, classify
from app.schemas import Confidence, RootCause, Symptom


class TestRuleCascade:
    """All 9 rows from rules_spec.md §2 worked-examples table."""

    # Row 1 — name_mismatch/medium (name_score 70-84, docs say nothing else)
    def test_row1_name_mismatch_medium(self):
        cause, conf = classify(RuleInput(
            name_score=78,
            dob_status="match",
            symptom=Symptom.turned_away_at_fps,
        ))
        assert cause == RootCause.name_mismatch, f"Expected name_mismatch, got {cause}"
        assert conf == Confidence.medium, f"Expected medium, got {conf}"

    # Row 2 — name_mismatch/high (user corroborates)
    def test_row2_name_mismatch_high_corroborated(self):
        cause, conf = classify(RuleInput(
            name_score=78,
            dob_status="match",
            symptom=Symptom.name_not_matching,
        ))
        assert cause == RootCause.name_mismatch, f"Expected name_mismatch, got {cause}"
        assert conf == Confidence.high, f"Expected high, got {conf}"

    # Row 3 — name_mismatch/high (name_score < 70)
    def test_row3_name_mismatch_high_low_score(self):
        cause, conf = classify(RuleInput(
            name_score=55,
            dob_status="unknown",
            symptom=Symptom.turned_away_at_fps,
        ))
        assert cause == RootCause.name_mismatch, f"Expected name_mismatch, got {cause}"
        assert conf == Confidence.high, f"Expected high, got {conf}"

    # Row 4 — dob_mismatch/high (name_score >= 85, dobs differ)
    def test_row4_dob_mismatch_high(self):
        cause, conf = classify(RuleInput(
            name_score=95,
            dob_status="mismatch",
            symptom=Symptom.turned_away_at_fps,
        ))
        assert cause == RootCause.dob_mismatch, f"Expected dob_mismatch, got {cause}"
        assert conf == Confidence.high, f"Expected high, got {conf}"

    # Row 5 — name_mismatch/medium (name_score 70-84 fires BEFORE dob mismatch)
    def test_row5_name_before_dob(self):
        cause, conf = classify(RuleInput(
            name_score=80,
            dob_status="mismatch",
            symptom=Symptom.other,
        ))
        assert cause == RootCause.name_mismatch, f"Expected name_mismatch, got {cause}"
        assert conf == Confidence.medium, f"Expected medium, got {conf}"

    # Row 6 — biometric_failure/high (rule 1 short-circuits everything)
    def test_row6_biometric_short_circuit(self):
        cause, conf = classify(RuleInput(
            name_score=96,
            dob_status="match",
            symptom=Symptom.biometric_failed,
        ))
        assert cause == RootCause.biometric_failure, (
            f"Expected biometric_failure, got {cause}"
        )
        assert conf == Confidence.high, f"Expected high, got {conf}"

    # Row 7 — seeding_gap/medium
    def test_row7_seeding_gap(self):
        cause, conf = classify(RuleInput(
            name_score=96,
            dob_status="match",
            symptom=Symptom.card_not_found,
        ))
        assert cause == RootCause.seeding_gap, f"Expected seeding_gap, got {cause}"
        assert conf == Confidence.medium, f"Expected medium, got {conf}"

    # Row 8 — ekyc_incomplete/low
    def test_row8_ekyc_incomplete(self):
        cause, conf = classify(RuleInput(
            name_score=96,
            dob_status="match",
            symptom=Symptom.turned_away_at_fps,
        ))
        assert cause == RootCause.ekyc_incomplete, (
            f"Expected ekyc_incomplete, got {cause}"
        )
        assert conf == Confidence.low, f"Expected low, got {conf}"

    # Row 9 — unknown/low (nothing fires)
    def test_row9_unknown_fallback(self):
        cause, conf = classify(RuleInput(
            name_score=96,
            dob_status="match",
            symptom=Symptom.other,
        ))
        assert cause == RootCause.unknown, f"Expected unknown, got {cause}"
        assert conf == Confidence.low, f"Expected low, got {conf}"
