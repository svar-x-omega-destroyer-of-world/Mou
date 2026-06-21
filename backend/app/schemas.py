"""Pydantic models mirroring contract/openapi.yaml (SRS v2.0 §5).

These are the wire types. Keep them in sync with the OpenAPI spec — the
contract is the source of truth, this file is its Python projection.
"""
from __future__ import annotations

from enum import Enum
from typing import Optional

from pydantic import BaseModel, Field


class RootCause(str, Enum):
    no_issues = "no_issues"          # documents match — no mismatch detected
    name_mismatch = "name_mismatch"
    dob_mismatch = "dob_mismatch"
    seeding_gap = "seeding_gap"
    ekyc_incomplete = "ekyc_incomplete"
    biometric_failure = "biometric_failure"
    unknown = "unknown"


class Confidence(str, Enum):
    high = "high"
    medium = "medium"
    low = "low"


class Symptom(str, Enum):
    turned_away_at_fps = "turned_away_at_fps"
    card_not_found = "card_not_found"
    biometric_failed = "biometric_failed"
    name_not_matching = "name_not_matching"
    other = "other"


class ExplanationSource(str, Enum):
    gemini = "gemini"
    fallback = "fallback"


class Extracted(BaseModel):
    aadhaar_name: str
    ration_name_script: str
    ration_name_romanized: str
    aadhaar_dob: Optional[str] = None
    ration_dob: Optional[str] = None


class NextStep(BaseModel):
    office: str
    form: str


class Diagnosis(BaseModel):
    root_cause: RootCause
    confidence: Confidence
    extracted: Extracted
    explanation: str
    next_step: NextStep
    disclaimer: str
    explanation_source: ExplanationSource = ExplanationSource.fallback
    case_id: str = ""


class FeedbackRequest(BaseModel):
    case_id: str
    root_cause: RootCause
    comment: Optional[str] = None


class FeedbackResponse(BaseModel):
    status: str = "ok"


class Case(BaseModel):
    case_id: str
    pattern: str


class Cluster(BaseModel):
    root_cause: RootCause
    fps_location: str
    beneficiaries_affected: int
    confidence: Confidence
    cases: list[Case] = Field(default_factory=list)
