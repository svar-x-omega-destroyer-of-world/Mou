"""Mou backend — FastAPI service (SRS v2.0 §3, §5).

Single source of truth for both frontends. Today it serves contract-compliant
mock responses so the Flutter app and Next.js dashboard can integrate on day 1.
The real pipeline lands behind the seams marked `# PHASE 2` / `# PHASE 3`:

    POST /diagnose : OCR -> field extraction -> transliteration-aware match
                     -> deterministic rules -> Gemini explanation (local fallback)
                     -> write anonymised event
    GET  /clusters : groupby(root_cause, location) over the event store, ranked

Nothing here decides eligibility (FR-10, FR-18). The dashboard is read-only.
"""
from __future__ import annotations

from typing import Optional

from fastapi import FastAPI, File, Form, UploadFile
from fastapi.middleware.cors import CORSMiddleware

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

    MOCK: returns the locked Rahima Begum example. Real pipeline (PHASE 2):
      1. PHASE 2  ocr.extract(aadhaar_image, ration_card_image)   # Risk R-1
      2. PHASE 2  matched = transliteration_match(fields)
      3. PHASE 2  cause, confidence = rules.classify(matched, symptom)   # FR-7
      4. PHASE 2  text, src = explain(cause, matched)   # Gemini + fallback (FR-11)
      5. PHASE 3  events.record(anonymise(cause, fps_location, pattern))  # FR-12
    """
    return Diagnosis(
        root_cause=RootCause.name_mismatch,
        confidence=Confidence.high,
        extracted=Extracted(
            aadhaar_name="Rahima Begum",
            ration_name_script="রহিমা বেগম",
            ration_name_romanized="Rahima Begam",
            aadhaar_dob="1989-03-12",
            ration_dob="1989-03-12",
        ),
        explanation=(
            "Your name appears slightly differently on your two documents. On "
            "your Aadhaar it reads 'Rahima Begum', but your ration card spells "
            "it 'Rahima Begam' (রহিমা বেগম). This small spelling difference is a "
            "common reason a ration is silently blocked at the shop."
        ),
        next_step=NextStep(office="Circle Office", form="RC Correction"),
        disclaimer=(
            "Likely cause — verify against your own documents before acting. "
            "This is not an eligibility decision."
        ),
        explanation_source=ExplanationSource.fallback,
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
