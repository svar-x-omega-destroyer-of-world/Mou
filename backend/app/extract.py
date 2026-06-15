"""Field extraction from OCR'd document text.

Takes the raw OCR output from ``ocr.extract_text()`` and pulls out the name
and date-of-birth fields we need for matching.  Handles English Aadhaar cards
and Bengali/English ration cards.

All extraction is regex-based and deterministic — no ML here.
"""
from __future__ import annotations

import re
from typing import Optional

from app.schemas import Extracted


# ---------------------------------------------------------------------------
# Date helpers
# ---------------------------------------------------------------------------

_DOB_PATTERNS = [
    # YYYY-MM-DD
    re.compile(r"(\d{4})[-/](\d{1,2})[-/](\d{1,2})"),
    # DD/MM/YYYY or DD-MM-YYYY
    re.compile(r"(\d{1,2})[-/](\d{1,2})[-/](\d{4})"),
]

# Normalise to YYYY-MM-DD
_NAMESPACE = {"month_names": {
    "jan": "01", "feb": "02", "mar": "03", "apr": "04",
    "may": "05", "jun": "06", "jul": "07", "aug": "08",
    "sep": "09", "oct": "10", "nov": "11", "dec": "12",
}}


def _normalise_dob(raw: str) -> str | None:
    """Try to parse and normalise a date string to YYYY-MM-DD."""
    s = raw.strip()
    for pat in _DOB_PATTERNS:
        m = pat.search(s)
        if m:
            g = m.groups()
            if len(g) == 3:
                # Try YYYY-MM-DD first
                if 1900 <= int(g[0]) <= 2100:
                    return f"{g[0]}-{int(g[1]):02d}-{int(g[2]):02d}"
                # Otherwise DD-MM-YYYY
                if 1900 <= int(g[2]) <= 2100:
                    return f"{g[2]}-{int(g[1]):02d}-{int(g[0]):02d}"
    return None


# ---------------------------------------------------------------------------
# Name extraction patterns
# ---------------------------------------------------------------------------

# Labels that precede the card-holder's name in Aadhaar-style documents
_AADHAAR_NAME_PATTERNS = [
    re.compile(r"(?:Name|नाम)[:\s]*([A-Z][A-Z\s.]+[A-Z])", re.IGNORECASE),
    re.compile(r"(?:Name of the Card Holder|Card Holder|Cardholder)[:\s]*([A-Z][A-Z\s.]+[A-Z])", re.IGNORECASE),
]

# Ration-card name markers (English labels → value; Bengali/Assamese → value)
_RATION_NAME_PATTERNS = [
    re.compile(r"Name of the Card Holder\s*:\s*(.+)", re.IGNORECASE),
    re.compile(r"Name of the Father / Husband\s*:\s*(.+)", re.IGNORECASE),
    re.compile(r"(?:Head of Family|পৰিয়ালৰ মুৰব্বী|পরিবারের প্রধান)\s*:\s*(.+)", re.IGNORECASE),
]

# DOB markers
_DOB_PREFIX_PATTERNS = [
    re.compile(r"(?:DOB|Date of Birth|Date Of Birth|জন্ম তারিখ|জন্ম|जन्म तिथि)[:\s]*([\d/\-A-Za-z]+)", re.IGNORECASE),
    re.compile(r"(?:Year of Birth|YOB)[:\s]*(\d{4})", re.IGNORECASE),
]


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

def extract_aadhaar(text: str) -> tuple[str | None, str | None]:
    """Extract name and DOB from Aadhaar-card OCR text.

    Returns:
        (name, dob) — either or both may be None if not found.
    """
    name = None
    for pat in _AADHAAR_NAME_PATTERNS:
        m = pat.search(text)
        if m:
            candidate = m.group(1).strip().title()
            # Filter out short / non-name matches
            if len(candidate.split()) >= 1 and len(candidate) >= 3:
                name = candidate
                break

    dob = None
    for pat in _DOB_PREFIX_PATTERNS:
        m = pat.search(text)
        if m:
            raw = m.group(1).strip()
            parsed = _normalise_dob(raw)
            if parsed:
                dob = parsed
                break

    return name, dob


def extract_ration(text: str) -> tuple[str | None, str | None]:
    """Extract name and DOB from ration-card OCR text.

    Returns:
        (name, dob) — name is kept in the original script
                      (Bengali or English); the matching layer handles
                      transliteration.
    """
    name = None
    for pat in _RATION_NAME_PATTERNS:
        m = pat.search(text)
        if m:
            candidate = m.group(1).strip()
            # Remove trailing noise
            candidate = re.sub(r"\s+", " ", candidate)
            if len(candidate) >= 3:
                name = candidate
                break

    dob = None
    for pat in _DOB_PREFIX_PATTERNS:
        m = pat.search(text)
        if m:
            raw = m.group(1).strip()
            parsed = _normalise_dob(raw)
            if parsed:
                dob = parsed
                break

    return name, dob


def extract_both(aadhaar_text: str, ration_text: str) -> Extracted:
    """Run full extraction on both document texts and return an Extracted.

    Args:
        aadhaar_text: OCR output from the Aadhaar image.
        ration_text: OCR output from the ration-card image.

    Returns:
        Extracted dataclass.  Missing fields are set to empty strings;
        the caller should validate before proceeding.
    """
    aadhaar_name, aadhaar_dob = extract_aadhaar(aadhaar_text)
    ration_name, ration_dob = extract_ration(ration_text)

    # Romanise the ration name for the Extracted response
    ration_romanised = ""
    if ration_name and any(ord(c) > 127 for c in ration_name):
        from app.matching import romanise
        try:
            ration_romanised = romanise(ration_name)
        except Exception:
            ration_romanised = ""

    return Extracted(
        aadhaar_name=aadhaar_name or "",
        ration_name_script=ration_name or "",
        ration_name_romanized=ration_romanised or (ration_name or ""),
        aadhaar_dob=aadhaar_dob,
        ration_dob=ration_dob,
    )
