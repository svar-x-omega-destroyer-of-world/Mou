#!/usr/bin/env python3
"""Mou — Task 1.1 OCR spike (Risk R-1).

Proves Google Cloud Vision can read Bengali text off real ration-card photos
BEFORE any matching/rules code is built.

Engine: Google Cloud Vision via REST API (DOCUMENT_TEXT_DETECTION) with an API
key. Language hints ['bn','hi','en']. If Vision is unavailable, a Tesseract
ben+eng fallback is provided (run with USE_TESSERACT=1) per rules_spec.md s4.

Run:
    cd backend
    ./.venv/bin/python spikes/ocr_spike.py

Requires `GOOGLE_VISION_API_KEY` in `backend/.env` (see .gitignore — never
committed). Put 1-3 real Bengali ration-card photos in backend/spikes/samples/
first.

# VERDICT: Google Cloud Vision DOCUMENT_TEXT_DETECTION with language hints
# ['bn','hi','en'] successfully extracts Bengali text from all 3 test photos
# (70–212 Bengali chars per image, incl. the key "Aklima Begum" name case).
# Quality is noticeably better than Tesseract — use Vision as primary OCR,
# Tesseract ben+eng as fallback (per rules_spec.md s4).
"""
from __future__ import annotations

import base64
import io
import os
import sys
from pathlib import Path

import httpx
from dotenv import load_dotenv

SAMPLES_DIR = Path(__file__).parent / "samples"
IMAGE_EXTS = {".jpg", ".jpeg", ".png", ".webp", ".bmp", ".tif", ".tiff"}
LANGUAGE_HINTS = ["bn", "hi", "en"]  # Bengali + Hindi + English
BENGALI_RANGE = range(0x0980, 0x0A00)  # legibility heuristic only
VISION_API_URL = "https://vision.googleapis.com/v1/images:annotate"


def _load_api_key() -> str | None:
    """Load the Vision API key from backend/.env or environment."""
    env_path = Path(__file__).parent.parent / ".env"
    if env_path.exists():
        load_dotenv(env_path)
    return os.environ.get("GOOGLE_VISION_API_KEY")


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
    """Fallback per rules_spec.md s4: Tesseract ben+eng."""
    import pytesseract
    from PIL import Image
    img = Image.open(io.BytesIO(image_bytes))
    return pytesseract.image_to_string(img, lang="ben+eng")


def bengali_char_count(text: str) -> int:
    return sum(1 for ch in text if ord(ch) in BENGALI_RANGE)


def main() -> int:
    use_tesseract = os.environ.get("USE_TESSERACT") == "1"

    api_key: str | None = None
    if not use_tesseract:
        api_key = _load_api_key()
        if not api_key:
            print("ERROR: GOOGLE_VISION_API_KEY not found. Set it in backend/.env")
            print("       or run with USE_TESSERACT=1.")
            return 1

    if not SAMPLES_DIR.exists():
        print(f"ERROR: Missing samples dir: {SAMPLES_DIR}")
        print("   Create it and add 1-3 Bengali ration-card photos.")
        return 1

    images = sorted(p for p in SAMPLES_DIR.iterdir() if p.suffix.lower() in IMAGE_EXTS)
    if not images:
        print(f"ERROR: No images in {SAMPLES_DIR}. Add 1-3 Bengali ration-card photos.")
        return 1

    engine = "Tesseract ben+eng" if use_tesseract else "Google Vision REST DOCUMENT_TEXT_DETECTION"
    print(f"Engine: {engine}")
    print(f"Samples: {len(images)} image(s) in {SAMPLES_DIR}\n")

    any_bengali = False
    for path in images:
        print("=" * 60)
        print(f"FILE: {path.name}")
        print("=" * 60)
        try:
            data = path.read_bytes()
            text = ocr_tesseract(data) if use_tesseract else ocr_google(data, api_key)
        except Exception as exc:  # spike: surface any failure, do not crash the loop
            print(f"  OCR failed: {exc}\n")
            continue
        bn = bengali_char_count(text)
        any_bengali = any_bengali or bn > 0
        print(text.strip() or "(no text returned)")
        print(f"\n  -> {len(text)} chars, {bn} Bengali characters\n")

    print("=" * 60)
    if any_bengali:
        print("PASS: Bengali text extracted from at least one photo.")
        print("Eyeball the name region above to confirm it is legible.")
    else:
        print("FAIL: no Bengali text found. Try DOCUMENT_TEXT_DETECTION→TEXT_DETECTION")
        print("in the features list, a higher-res photo, or USE_TESSERACT=1.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
