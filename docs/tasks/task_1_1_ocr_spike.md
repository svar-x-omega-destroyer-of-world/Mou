# Task 1.1 — OCR Spike (Risk R-1) — executor card

> Hand this whole card to the builder. It is **self-contained** — all code you need
> is embedded below, so you do not need to open any other project. One task, one
> concern. Run the acceptance test before declaring done. Re-read `CLAUDE.md`
> §Invariants first.
>
> **What "spike" means:** a small throwaway experiment that tests the single riskiest
> unknown before any real code is built. Here the unknown is: *can OCR actually read
> the name off a real ration-card photo?* Nothing else is built in this task.

## Provenance — this is Mou's OWN OCR, ported from the team's electoral pipeline
Mou's OCR is **the same Google Cloud Vision approach the team already built** for its
electoral pipeline (`~/Documents/ec`, specifically `google_extract_voters.py`). We
**copy that approach into Mou** so Mou owns its OCR code — Mou does not depend on,
run, or modify `ec`, and does not use its credentials. The relevant logic (the Vision
call + language hints) is already adapted and embedded in this card. Vision is the
engine because that is what the team's own pipeline uses; the only change is that Mou
authenticates with **its own fresh Vision API key** (a direct REST call) instead of a
shared service-account file.

## Goal
Prove **the ported OCR reads the name region off a real ration-card photo** —
**whatever the script** (English, Bengali, or bilingual) — before any matching/rules
code exists. This is the #1 risk on the build. Output is a single script that OCRs
the photos in `backend/spikes/samples/` and reports PASS/FAIL.

> Note: Indian ration cards are generally **bilingual** (local language + English/Hindi),
> and older cards may be **entirely in the local language**. Assume **multilingual
> input**, not English-only. PASS requires the **name** to be legibly extracted in
> whatever script(s) appear — it does NOT require, nor exclude, Bengali. The Bengali
> character count is reported as info. `languageHints=['bn','hi','en']` covers all
> three cases.

## Prerequisite
**Task 1.0 (place Mou's own Vision API key) must be done first.** Mou authenticates
with its **own fresh Vision API key**, read from `GOOGLE_VISION_API_KEY` (env var, or
`backend/spikes/.env`). Do not use any other project's key.

## Inputs (provided by the human, not you)
- The human places **1–3 real ration-card photos** (multilingual) in `backend/spikes/samples/`.
- Mou's own Vision API key is in `GOOGLE_VISION_API_KEY` (env var or `backend/spikes/.env`,
  from Task 1.0). The spike reads it automatically.
- The `~/Documents/ec` project is a **read-only reference** only — it shows *how* to
  call Vision (see `google_extract_voters.py`). You should not need to open it; the
  approach is already embedded below.

## OFF-LIMITS — do not touch
- **`~/Documents/ec/pre testing/`** (note the space in the folder name) is strictly
  off-limits. Do **not** open, read, browse, run, or learn anything from any file
  inside it. It is not a reference and has nothing to do with Mou.
- The rest of `~/Documents/ec` is read-only reference at most; do not run or modify it,
  and never use its credentials or API key.

## Files to create / modify

### 1. CREATE `backend/spikes/ocr_spike.py` — write exactly:
```python
#!/usr/bin/env python3
"""Mou — Task 1.1 OCR spike (Risk R-1).

Proves Google Cloud Vision can read the name off real ration-card photos
BEFORE any matching/rules code is built.

Engine: Google Cloud Vision REST API (images:annotate, DOCUMENT_TEXT_DETECTION),
authenticated with Mou's OWN fresh API key. Language hints ['bn','hi','en']. If
Vision is unavailable, a Tesseract ben+eng fallback is provided (run with
USE_TESSERACT=1) per rules_spec.md s4.

Credentials: Mou's own Vision API key in env var GOOGLE_VISION_API_KEY, or in a
gitignored backend/spikes/.env file as GOOGLE_VISION_API_KEY=AIza... . The key is
NEVER hardcoded and NEVER committed.

Run:
    cd backend
    ./.venv/bin/python spikes/ocr_spike.py

Put 1-3 real ration-card photos (multilingual) in backend/spikes/samples/ first.
NEVER commit the .env key file or the sample photos (see .gitignore).

# VERDICT: <fill in one sentence after running: is Vision good enough or not?>
"""
from __future__ import annotations

import base64
import io
import os
import sys
from pathlib import Path

SAMPLES_DIR = Path(__file__).parent / "samples"
ENV_FILE = Path(__file__).parent / ".env"
IMAGE_EXTS = {".jpg", ".jpeg", ".png", ".webp", ".bmp", ".tif", ".tiff"}
LANGUAGE_HINTS = ["bn", "hi", "en"]  # Bengali + Hindi + English
BENGALI_RANGE = range(0x0980, 0x0A00)  # legibility heuristic only
VISION_URL = "https://vision.googleapis.com/v1/images:annotate"


def _resolve_api_key() -> str | None:
    """Find Mou's own Vision API key. Env var wins; else read gitignored .env.
    Never hardcode the key; never commit it."""
    key = os.environ.get("GOOGLE_VISION_API_KEY")
    if key:
        return key.strip()
    if ENV_FILE.exists():
        for line in ENV_FILE.read_text().splitlines():
            line = line.strip()
            if line.startswith("GOOGLE_VISION_API_KEY="):
                return line.split("=", 1)[1].strip().strip('"').strip("'")
    return None


def ocr_google(image_bytes: bytes, api_key: str) -> str:
    """Call Google Cloud Vision REST with an API key (no service account).
    Mirrors the team's electoral pipeline approach, ported into Mou."""
    import httpx  # already a backend dependency
    payload = {
        "requests": [
            {
                "image": {"content": base64.b64encode(image_bytes).decode("ascii")},
                # DOCUMENT_TEXT_DETECTION is tuned for dense document photos. If
                # results are poor, swap this to "TEXT_DETECTION".
                "features": [{"type": "DOCUMENT_TEXT_DETECTION"}],
                "imageContext": {"languageHints": LANGUAGE_HINTS},
            }
        ]
    }
    resp = httpx.post(VISION_URL, params={"key": api_key}, json=payload, timeout=60.0)
    resp.raise_for_status()
    data = resp.json()["responses"][0]
    if "error" in data and data["error"].get("message"):
        raise RuntimeError(f"Vision error: {data['error']['message']}")
    fta = data.get("fullTextAnnotation")
    return fta["text"] if fta else ""


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
    engine = "Tesseract ben+eng" if use_tesseract else "Google Vision REST (API key)"

    api_key = None
    if not use_tesseract:
        api_key = _resolve_api_key()
        if not api_key:
            print("ERROR: No Vision API key. Put GOOGLE_VISION_API_KEY in the "
                  "environment or in backend/spikes/.env, or run with USE_TESSERACT=1.")
            return 1

    if not SAMPLES_DIR.exists():
        print(f"ERROR: Missing samples dir: {SAMPLES_DIR}")
        print("   Create it and add 1-3 ration-card photos.")
        return 1

    images = sorted(p for p in SAMPLES_DIR.iterdir() if p.suffix.lower() in IMAGE_EXTS)
    if not images:
        print(f"ERROR: No images in {SAMPLES_DIR}. Add 1-3 ration-card photos.")
        return 1

    print(f"Engine: {engine}")
    print(f"Samples: {len(images)} image(s) in {SAMPLES_DIR}\n")

    any_text = False
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
        if text.strip():
            any_text = True
        script = "Bengali present" if bn else "Latin/other only"
        print(text.strip() or "(no text returned)")
        print(f"\n  -> {len(text)} chars, {bn} Bengali chars ({script})\n")

    print("=" * 60)
    if any_text:
        print("PASS: text extracted from at least one photo.")
        print("Eyeball the NAME region above to confirm it is legible —")
        print("this works the same whether the card is English, Bengali, or bilingual.")
    else:
        print("FAIL: no text extracted. Try TEXT_DETECTION instead of")
        print("DOCUMENT_TEXT_DETECTION, a higher-res photo, or USE_TESSERACT=1.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
```

### 2. CREATE `backend/spikes/samples/.gitkeep` — empty file (keeps the folder in git; the photos themselves are gitignored).

### 3. MODIFY `backend/requirements.txt` — no new package needed.
The spike calls Vision over REST with `httpx`, which is **already** pinned in
`requirements.txt`. The old `google-cloud-vision` client is no longer required for the
spike; leave it as-is or comment it out. Do **not** add `pytesseract` / `Pillow` —
they are only for the optional Tesseract fallback and can be installed ad hoc.

### 4. `.gitignore` (repo root) — ALREADY DONE. It already ignores `.env` / `.env.*`
and `backend/spikes/samples/*`. Do not touch it.

## Run
```bash
cd "/Users/naiwritjoyshukla/Documents/Claude Code Terminal/projects/Mou/backend"
python3 -m venv .venv                        # if .venv does not exist
./.venv/bin/pip install -r requirements.txt
# Mou's own key from Task 1.0 lives in backend/spikes/.env (GOOGLE_VISION_API_KEY=...)
# and is read automatically. Or export it instead:
# export GOOGLE_VISION_API_KEY=AIza...
./.venv/bin/python spikes/ocr_spike.py
```

## Acceptance
- Script prints the **legible name region** for at least one real photo and ends
  with `PASS`. The name may be in English, Bengali, or both — a human eyeballs the
  printed text to confirm the name is readable. The Bengali-char count is only
  informational (tells us whether the regional-script path is exercised).
- If it prints `FAIL` or text is garbled: try swapping the feature `"type"` from
  `DOCUMENT_TEXT_DETECTION` to `TEXT_DETECTION`; if Vision still fails, run with
  `USE_TESSERACT=1` after `./.venv/bin/pip install pytesseract Pillow` (needs a
  system `tesseract` + `ben` language pack), per `rules_spec.md §4`.

## Definition of Done
- Fill in the `# VERDICT:` line at the top of `ocr_spike.py` with one sentence:
  is Google Vision good enough for these multilingual ration cards, or do we use the
  Tesseract / curated-pair fallback?

## Do NOT
- Do NOT open, read, run, or learn from `~/Documents/ec/pre testing/` (off-limits).
- Do NOT modify, run, or import from the `~/Documents/ec` project. You may **copy its
  OCR approach into Mou** (the Vision call + language hints — already embedded above,
  so you shouldn't need to open it), but `ec` stays untouched and is never a runtime
  dependency.
- Do NOT use `ec`'s credentials or API key. Mou uses its **own** fresh key from Task 1.0.
- Do NOT hardcode any API key anywhere — env var / `.env` only.
- Do NOT commit `backend/spikes/.env` or the sample photos.
- Do NOT build matching/rules/extraction logic — this is a spike only.
- Do NOT touch the contract, the backend mock endpoints, or any unrelated file.
