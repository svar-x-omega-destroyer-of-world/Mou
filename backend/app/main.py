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

from .events import get_clusters as _get_clusters, record_event, record_feedback
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
    FeedbackRequest,
    FeedbackResponse,
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


def _document_pattern(cause: RootCause, ns: int, ds: str, extracted: Extracted) -> str:
    """Generate a short, anonymised pattern descriptor for the event store.

    Examples: "Begum/Begam", "1989/1998", "aadhaar_not_seeded".
    """
    if cause == RootCause.name_mismatch and extracted.aadhaar_name and extracted.ration_name_script:
        # Short descriptor: extract differing tokens
        a_tokens = extracted.aadhaar_name.lower().split()
        r_tokens = extracted.ration_name_script.lower().split()
        diff = []
        for a, r in zip(a_tokens, r_tokens):
            if a != r:
                diff.append(f"{a}/{r}")
        return "/".join(diff[:2]) if diff else "name_diff"
    if cause == RootCause.dob_mismatch and extracted.aadhaar_dob and extracted.ration_dob:
        return f"{extracted.aadhaar_dob[:4]}/{extracted.ration_dob[:4]}"
    # Fixed patterns for other causes
    return {
        RootCause.biometric_failure: "fingerprint_worn",
        RootCause.seeding_gap: "aadhaar_not_seeded",
        RootCause.ekyc_incomplete: "ekyc_incomplete",
        RootCause.unknown: "unknown",
    }.get(cause, "other")


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

    # 6. Anonymised event record (FR-12)
    pattern = _document_pattern(cause, ns, ds, extracted)
    try:
        record_event(
            root_cause=cause,
            confidence=confidence,
            fps_location=fps_location,
            document_pattern=pattern,
        )
    except Exception:
        pass  # event recording must never break the diagnosis

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
def clusters(min_confidence: Optional[Confidence] = Confidence.medium) -> list[Cluster]:
    """Return systemic-defect clusters, ranked by beneficiaries affected.

    Computed from the event store: group by (root_cause, fps_location),
    rank by distinct beneficiary count descending (FR-13/14).
    Default hides low-confidence noise; pass low to see everything (FR-16).
    """
    return _get_clusters(min_confidence=min_confidence)


@app.post("/feedback", response_model=FeedbackResponse)
def feedback(body: FeedbackRequest) -> FeedbackResponse:
    """Record flag-as-incorrect feedback from a user (FR-19/20).

    Stores the case_id, root_cause, and optional free-text comment so
    officials can review disputed diagnoses.  No PII is stored.
    """
    record_feedback(
        case_id=body.case_id,
        root_cause=body.root_cause,
        comment=body.comment,
    )
    return FeedbackResponse()
