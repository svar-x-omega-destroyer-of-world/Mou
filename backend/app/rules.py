"""Deterministic root-cause classifier (rules_spec.md §2).

Exactly one primary root cause per diagnosis (FR-7).  No LLM on this path
(FR-18).  The cascade is evaluated top-to-bottom; the first matching rule
wins.  Do not reorder, add, or remove rules without consulting the spec.
"""
from __future__ import annotations

from dataclasses import dataclass
from typing import Tuple

from app.schemas import Confidence, RootCause, Symptom


@dataclass(frozen=True)
class RuleInput:
    """The full input to the rule classifier after OCR + matching."""

    name_score: int       # 0–100 transliteration-aware similarity (§3)
    dob_status: str       # "match" | "mismatch" | "unknown"
    symptom: str          # one of Symptom enum values (intake)


# Convenience type alias
_RuleResult = Tuple[RootCause, Confidence]


def classify(inp: RuleInput) -> _RuleResult:
    """Run the rule cascade (FIRST match wins).

    Args:
        inp: RuleInput with the post-matching fields.

    Returns:
        (root_cause, confidence) — exactly one primary root cause.
    """
    symptom = inp.symptom
    ns = inp.name_score

    # ── RULE 1 — Biometric failure (hard symptom, documents irrelevant) ──
    if symptom == Symptom.biometric_failed:
        return (RootCause.biometric_failure, Confidence.high)

    # ── RULE 2 — Name mismatch (the flagship; objective document evidence) ──
    if ns < 85:
        if ns < 70:
            conf = Confidence.high
        else:  # 70–84 → transliteration-level variance
            conf = Confidence.medium

        if symptom == Symptom.name_not_matching:
            conf = Confidence.high  # user corroborates → upgrade

        return (RootCause.name_mismatch, conf)

    # ── RULE 3 — Date-of-birth mismatch ──
    if inp.dob_status == "mismatch":
        conf = Confidence.high if ns >= 85 else Confidence.medium
        return (RootCause.dob_mismatch, conf)

    # ── RULE 4 — Seeding gap (docs clean, but card not found at shop) ──
    if symptom == Symptom.card_not_found:
        return (RootCause.seeding_gap, Confidence.medium)

    # ── RULE 5 — e-KYC incomplete (docs clean, turned away) ──
    if symptom == Symptom.turned_away_at_fps:
        return (RootCause.ekyc_incomplete, Confidence.low)

    # ── RULE 6 / FALLBACK — nothing fired confidently ──
    return (RootCause.unknown, Confidence.low)
