"""OCR module — primary: Google Cloud Vision REST, fallback: Tesseract (FR-4).

Port of the OCR spike (backend/spikes/ocr_spike.py) into the real pipeline.
Calls Vision over REST with the project's own API key (Task 1.0).  If the
image is too blurry or unreadable, raises ``UnreadableImageError`` which the
endpoint translates to HTTP 422.
"""
from __future__ import annotations

import base64
import io
import os
from pathlib import Path

import httpx
from dotenv import load_dotenv

# ── Config ──────────────────────────────────────────────────────────────────
LANGUAGE_HINTS = ["bn", "hi", "en"]
VISION_API_URL = "https://vision.googleapis.com/v1/images:annotate"
ENV_KEY_NAME = "GOOGLE_VISION_API_KEY"
TESSERACT_MIN_BENGALI = 5  # fall back to Tesseract if Vision returns < this
MIN_TEXT_LENGTH = 20  # below this → UnreadableImageError


class UnreadableImageError(ValueError):
    """Raised when OCR cannot extract meaningful text (FR-4 → HTTP 422)."""
    pass


def _load_api_key() -> str | None:
    """Load Vision API key from environment or backend/.env."""
    # Already loaded?  Try environ first so tests can set it programmatically.
    key = os.environ.get(ENV_KEY_NAME)
    if key:
        return key
    # Fall back to .env next to this file's project root
    env_path = Path(__file__).resolve().parent.parent / ".env"
    if env_path.exists():
        load_dotenv(env_path)
    return os.environ.get(ENV_KEY_NAME)


# ---------------------------------------------------------------------------
# OCR engines
# ---------------------------------------------------------------------------

def ocr_google(image_bytes: bytes, api_key: str) -> str:
    """Call Google Cloud Vision REST API — DOCUMENT_TEXT_DETECTION."""
    encoded = base64.b64encode(image_bytes).decode("ascii")
    payload = {
        "requests": [{
            "image": {"content": encoded},
            "features": [{"type": "DOCUMENT_TEXT_DETECTION"}],
            "imageContext": {"languageHints": LANGUAGE_HINTS},
        }]
    }
    resp = httpx.post(
        VISION_API_URL,
        params={"key": api_key},
        json=payload,
        timeout=30,
    )
    result = resp.json()
    if resp.status_code != 200:
        err = result.get("error", {})
        msg = err.get("message", resp.text)
        raise RuntimeError(f"Vision API error ({resp.status_code}): {msg}")

    responses = result.get("responses", [])
    if not responses:
        return ""
    annotation = responses[0].get("fullTextAnnotation")
    return annotation.get("text", "") if annotation else ""


def ocr_tesseract(image_bytes: bytes) -> str:
    """Fallback OCR using Tesseract ben+eng (rules_spec.md §4)."""
    import pytesseract
    from PIL import Image
    img = Image.open(io.BytesIO(image_bytes))
    return pytesseract.image_to_string(img, lang="ben+eng")


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

def extract_text(image_bytes: bytes) -> str:
    """Extract text from a document photo, with fallback chain.

    Args:
        image_bytes: Raw image bytes (JPEG/PNG/…).

    Returns:
        Extracted text string.

    Raises:
        UnreadableImageError: If no engine could extract meaningful text
            (caller should return HTTP 422).
    """
    api_key = _load_api_key()

    # Try Vision first (primary engine)
    if api_key:
        text = ocr_google(image_bytes, api_key)
        if len(text.strip()) >= MIN_TEXT_LENGTH:
            # Heuristic check: enough Bengali chars to be a real document
            bn_count = sum(1 for ch in text if 0x0980 <= ord(ch) <= 0x09FF)
            if bn_count >= TESSERACT_MIN_BENGALI or len(text) >= 100:
                return text.strip()

    # Fallback: Tesseract
    try:
        text = ocr_tesseract(image_bytes)
        if len(text.strip()) >= MIN_TEXT_LENGTH:
            return text.strip()
    except Exception:
        pass

    raise UnreadableImageError(
        "The document photo is too blurry to read. "
        "Please retake with better lighting and ensure the text is in focus."
    )
