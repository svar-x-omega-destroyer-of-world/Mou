"""Mou backend — FastAPI service (SRS v2.0 §3, §5).

Single source of truth for both frontends.

    POST /diagnose : OCR -> field extraction -> transliteration-aware match
                     -> deterministic rules -> Gemini explanation (local fallback)
                     -> write anonymised event
    GET  /clusters : groupby(root_cause, location) over the event store, ranked

Nothing here decides eligibility (FR-10, FR-18). The dashboard is read-only.
"""
from __future__ import annotations

from typing import Optional

from fastapi import FastAPI, File, Form, UploadFile, HTTPException
from fastapi.middleware.cors import CORSMiddleware

from .extract import extract_both
from .matching import dob_status, name_score
from .ocr import UnreadableImageError, extract_text
from .rules import RuleInput, classify
from .explain import explain
from .schemas import (
    Case,
    Cluster,
    Confidence,
    Diagnosis,
    ExplanationSource,
    Extracted,
    NextStep,
    RootCause,
    Symptom,
)

app = FastAPI(title="Mou API", version="2.0")

# Frontends run on other origins (Flutter web debug, Vercel dashboard, etc.).
# Wide-open for the hackathon demo; tighten before any real deployment.
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)


# ── Helpers ─────────────────────────────────────────────────────────────────

_DISCLAIMER = (
    "Likely cause — verify against your own documents before acting. "
    "This is not an eligibility decision."
)

_NEXT_STEPS: dict[str, NextStep] = {
    RootCause.name_mismatch: NextStep(office="Circle Office", form="RC Correction"),
    RootCause.dob_mismatch: NextStep(office="Circle Office", form="DOB Correction"),
    RootCause.seeding_gap: NextStep(office="Circle Office", form="Aadhaar Seeding"),
    RootCause.ekyc_incomplete: NextStep(office="Circle Office", form="e-KYC Completion"),
    RootCause.biometric_failure: NextStep(office="FPS / Circle Office", form="Alternate Auth Registration"),
    RootCause.unknown: NextStep(office="Circle Office", form="Manual Record Check"),
}


def _next_step(root_cause: RootCause) -> NextStep:
    return _NEXT_STEPS.get(root_cause, _NEXT_STEPS[RootCause.unknown])


# ── Endpoints ───────────────────────────────────────────────────────────────

@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok"}


@app.post("/diagnose", response_model=Diagnosis)
async def diagnose(
    aadhaar_image: UploadFile = File(...),
    ration_card_image: UploadFile = File(...),
    symptom: Symptom = Form(...),
    fps_location: Optional[str] = Form(None),
    language: Optional[str] = Form(None),
) -> Diagnosis:
    """Return the likely root cause for a single case.

    Pipeline:
      1. OCR both images (Vision REST → Tesseract fallback).
      2. Extract Aadhaar name + DOB and ration name + DOB.
      3. Transliteration-aware name match (name_score, dob_status).
      4. Deterministic rules (rules.classify).
      5. Gemini explanation with local fallback (explain).
      6. (Phase 3) Anonymised event recorded.
    """
    # 1. OCR — read both images
    try:
        aadhaar_bytes = await aadhaar_image.read()
        ration_bytes = await ration_card_image.read()
    except Exception as exc:
        raise HTTPException(400, detail=f"Failed to read upload: {exc}")

    try:
        aadhaar_text = extract_text(aadhaar_bytes)
        ration_text = extract_text(ration_bytes)
    except UnreadableImageError as exc:
        raise HTTPException(422, detail={"error": "unreadable_image", "message": str(exc)})

    # 2. Field extraction
    extracted = extract_both(aadhaar_text, ration_text)

    # 3. Matching
    ns = name_score(extracted.aadhaar_name, extracted.ration_name_script)
    ds = dob_status(extracted.aadhaar_dob, extracted.ration_dob)

    # 4. Root-cause classification
    cause, confidence = classify(RuleInput(
        name_score=ns,
        dob_status=ds,
        symptom=symptom.value,
    ))

    # 5. Explanation
    explanation_text, explanation_source = explain(
        root_cause=cause,
        confidence=confidence,
        extracted=extracted,
        symptom=symptom.value,
        fps_location=fps_location,
    )

    return Diagnosis(
        root_cause=cause,
        confidence=confidence,
        extracted=extracted,
        explanation=explanation_text,
        next_step=_next_step(cause),
        disclaimer=_DISCLAIMER,
        explanation_source=explanation_source,
    )


@app.get("/clusters", response_model=list[Cluster])
def clusters(min_confidence: Optional[Confidence] = None) -> list[Cluster]:
    """Return systemic-defect clusters, ranked by beneficiaries affected.

    MOCK: returns seeded synthetic clusters. Real implementation (PHASE 3):
      rows = events.all()
      clusters = groupby(rows, key=(root_cause, fps_location))   # FR-13
      rank by distinct beneficiaries desc                        # FR-14
      drop clusters below the confidence threshold               # FR-16
    """
    data = [
        Cluster(
            root_cause=RootCause.name_mismatch,
            fps_location="Silchar FPS #4471",
            beneficiaries_affected=40,
            confidence=Confidence.high,
            cases=[
                Case(case_id="anon-0192", pattern="Begum/Begam"),
                Case(case_id="anon-0211", pattern="Khatun/Khatoon"),
                Case(case_id="anon-0233", pattern="Rahman/Rehman"),
            ],
        ),
        Cluster(
            root_cause=RootCause.seeding_gap,
            fps_location="Karimganj FPS #2210",
            beneficiaries_affected=27,
            confidence=Confidence.high,
            cases=[
                Case(case_id="anon-0301", pattern="aadhaar_not_seeded"),
                Case(case_id="anon-0318", pattern="aadhaar_not_seeded"),
            ],
        ),
        Cluster(
            root_cause=RootCause.biometric_failure,
            fps_location="Hailakandi FPS #1180",
            beneficiaries_affected=14,
            confidence=Confidence.medium,
            cases=[Case(case_id="anon-0402", pattern="fingerprint_worn")],
        ),
        Cluster(
            root_cause=RootCause.dob_mismatch,
            fps_location="Silchar FPS #4471",
            beneficiaries_affected=6,
            confidence=Confidence.low,
            cases=[Case(case_id="anon-0501", pattern="1989/1998")],
        ),
    ]

    order = {Confidence.high: 3, Confidence.medium: 2, Confidence.low: 1}
    if min_confidence is not None:
        data = [c for c in data if order[c.confidence] >= order[min_confidence]]
    data.sort(key=lambda c: c.beneficiaries_affected, reverse=True)
    return data
