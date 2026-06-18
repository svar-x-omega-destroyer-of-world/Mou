"""Explanation layer: Gemini → personalised text, with local fallback (FR-11).

The explanation is the only place an LLM is used (FR-18).  The root cause is
always chosen by deterministic rules in ``rules.py``.  If Gemini is unavailable
or errors, ``explain()`` returns a pre-written fallback string and sets
``explanation_source = "fallback"``.  The endpoint never 500s.
"""
from __future__ import annotations

import os
from pathlib import Path
from typing import Optional

from dotenv import load_dotenv

from app.fallbacks import get_fallback

# Load .env from backend/ directory (same as ocr.py does for Vision key)
_env_path = Path(__file__).resolve().parent.parent / ".env"
if _env_path.exists():
    load_dotenv(_env_path, override=True)
from app.schemas import Confidence, ExplanationSource, Extracted, RootCause

GEMINI_MODEL = "gemini-2.5-flash"
GEMINI_API_KEY_ENV = "GEMINI_API_KEY"

# ── Instruct template ───────────────────────────────────────────────────────
# System-like instruction for the Gemini call.  Kept here so the full prompt
# is visible and auditable.

_SYSTEM_INSTRUCTION = """You are an assistant for a public-benefit tool called Mou.
You help a citizen understand why their ration card may have been silently
defective at a Fair Price Shop.

Rules:
1. Explain the LIKELY root cause in plain, simple language (approximately B1
   English or simpler — short sentences, common words).
2. Always frame it as "Likely cause" — NEVER state that the person qualifies
   or does not qualify for rations.  You are not an eligibility authority.
3. Mention both document names if you have them, but do NOT quote full Aadhaar
   numbers or other identifiers.
4. End with a concrete "As a next step" suggestion.
5. Keep the total explanation under 120 words.
6. Output only the explanation text — no preamble, no labels.
"""

# ── Template prompt ─────────────────────────────────────────────────────────

_EXPLAIN_PROMPT = """Root cause: {root_cause}
Confidence: {confidence}
Aadhaar name: {aadhaar_name}
Ration card name (script): {ration_name_script}
Ration card name (romanised): {ration_name_romanized}
Symptom reported: {symptom}
FPS location: {fps_location}

Explain the likely cause and a next step."""


def _try_gemini(
    root_cause: str,
    confidence: str,
    extracted: Extracted,
    symptom: str,
    fps_location: Optional[str],
) -> Optional[str]:
    """Call Gemini to generate a personalised explanation.

    Returns:
        Explanation string on success, or None on any error (auth, network,
        API error, etc.).
    """
    api_key = os.environ.get(GEMINI_API_KEY_ENV)
    if not api_key:
        return None  # no key configured → fallback

    try:
        from google import genai
        from google.genai import types

        client = genai.Client(api_key=api_key)
        prompt = _EXPLAIN_PROMPT.format(
            root_cause=root_cause,
            confidence=confidence,
            aadhaar_name=extracted.aadhaar_name,
            ration_name_script=extracted.ration_name_script,
            ration_name_romanized=extracted.ration_name_romanized,
            symptom=symptom,
            fps_location=fps_location or "not provided",
        )
        resp = client.models.generate_content(
            model=GEMINI_MODEL,
            contents=prompt,
            config=types.GenerateContentConfig(
                system_instruction=_SYSTEM_INSTRUCTION,
            ),
        )
        t = resp.text
        return t.strip() if t else None
    except Exception:
        return None


def explain(
    root_cause: RootCause,
    confidence: Confidence,
    extracted: Extracted,
    symptom: str,
    fps_location: Optional[str] = None,
) -> tuple[str, ExplanationSource]:
    """Generate an explanation, trying Gemini first then falling back locally.

    Args:
        root_cause: The deterministic root cause from ``rules.classify()``.
        confidence: The confidence level.
        extracted: The fields extracted from both documents.
        symptom: The symptom reported by the user.
        fps_location: Optional FPS location string.

    Returns:
        (explanation_text, explanation_source):
          - ``explanation_source == "gemini"`` when the LLM succeeded.
          - ``explanation_source == "fallback"`` when it didn't.
    """
    text = _try_gemini(
        root_cause.value,
        confidence.value,
        extracted,
        symptom,
        fps_location,
    )
    if text:
        return text, ExplanationSource.gemini

    # Gemini unavailable or errored → local fallback (Risk R-4)
    return get_fallback(root_cause.value), ExplanationSource.fallback
