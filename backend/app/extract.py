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
    # DD Mon YYYY — "01 Jan 1990", "1-JAN-1990", "01.Mar.2001"
    re.compile(r"(\d{1,2})[\s\-/\.]([A-Za-z]{3,9})[\s\-/\.](\d{4})"),
]

_MONTH_NAMES = {
    "jan": 1, "feb": 2, "mar": 3, "apr": 4, "may": 5, "jun": 6,
    "jul": 7, "aug": 8, "sep": 9, "oct": 10, "nov": 11, "dec": 12,
    "january": 1, "february": 2, "march": 3, "april": 4,
    "june": 6, "july": 7, "august": 8, "september": 9,
    "october": 10, "november": 11, "december": 12,
}


def _normalise_dob(raw: str) -> str | None:
    """Try to parse and normalise a date string to YYYY-MM-DD.

    Validates month (1-12) and day (1-31) ranges to reject OCR garbage.
    Handles: YYYY-MM-DD, DD/MM/YYYY, DD-MM-YYYY, DD-Mon-YYYY, DD Mon YYYY.
    """
    s = raw.strip()

    # Numeric-only patterns (YYYY-MM-DD and DD/MM/YYYY)
    for pat in _DOB_PATTERNS[:2]:
        m = pat.search(s)
        if m:
            g = m.groups()
            if 1900 <= int(g[0]) <= 2100:
                month, day = int(g[1]), int(g[2])
                if 1 <= month <= 12 and 1 <= day <= 31:
                    return f"{g[0]}-{month:02d}-{day:02d}"
            if 1900 <= int(g[2]) <= 2100:
                day, month = int(g[0]), int(g[1])
                if 1 <= month <= 12 and 1 <= day <= 31:
                    return f"{g[2]}-{month:02d}-{day:02d}"

    # Month-name pattern: DD-Mon-YYYY
    m = _DOB_PATTERNS[2].search(s)
    if m:
        day, mon_str, year = int(m.group(1)), m.group(2).lower()[:3], int(m.group(3))
        month = _MONTH_NAMES.get(mon_str)
        if month and 1 <= day <= 31 and 1900 <= year <= 2100:
            return f"{year}-{month:02d}-{day:02d}"

    return None


# ---------------------------------------------------------------------------
# Name extraction patterns
# ---------------------------------------------------------------------------

# Labels that precede the card-holder's name in Aadhaar-style documents.
# [A-Z .] instead of [A-Z\s.] — \s matches \n and would swallow DOB/address lines.
_AADHAAR_NAME_PATTERNS = [
    re.compile(r"(?:Name|नाम)[:\s]*([A-Z][A-Z .]{1,58}[A-Za-z])", re.IGNORECASE),
    re.compile(r"(?:Name of the Card Holder|Card Holder|Cardholder)[:\s]*([A-Z][A-Z .]{1,58}[A-Za-z])", re.IGNORECASE),
]

# Ration-card name markers.
# Capture group limited to 60 chars of name-safe chars — stops at digits/Bengali
# digits/punctuation that mark the start of the next field when OCR drops newlines.
_NAME_CHARS = r"[A-Za-zঀ-৿ .']{2,60}"
_RATION_NAME_PATTERNS = [
    re.compile(r"Name of the Card Holder\s*:\s*(" + _NAME_CHARS + r")", re.IGNORECASE),
    re.compile(r"Card Holder\s*:\s*(" + _NAME_CHARS + r")", re.IGNORECASE),
    re.compile(r"Cardholder\s*:\s*(" + _NAME_CHARS + r")", re.IGNORECASE),
    re.compile(r"(?:Name|নাম)[:\s]*(" + _NAME_CHARS + r")", re.IGNORECASE),
    re.compile(r"Name of the Father / Husband\s*:\s*(" + _NAME_CHARS + r")", re.IGNORECASE),
    re.compile(r"(?:Head of Family|পৰিয়ালৰ মুৰব্বী|পরিবারের প্রধান)\s*:\s*(" + _NAME_CHARS + r")", re.IGNORECASE),
]

# DOB markers — [\d/\-\. A-Za-z]+ covers "01 Jan 1990", "01.01.1990", "01/01/1990"
_DOB_PREFIX_PATTERNS = [
    re.compile(r"(?:DOB|Date of Birth|Date Of Birth|জন্ম তারিখ|জন্ম|जन्म तिथि)[:\s]*([\d/\-\. A-Za-z]{6,20})", re.IGNORECASE),
    re.compile(r"(?:Year of Birth|YOB)[:\s]*(\d{4})", re.IGNORECASE),
]

# Field labels of the *next* field that can bleed into a name capture when OCR
# drops the newline between the name and the field below it (e.g. Vision
# returning "Name Dino Saren Date Of Birth 01/01/1990" on one line).  We cut the
# captured name at the first occurrence of any of these.  \b anchors keep us from
# clipping legitimate name tokens that merely contain these letters.
_TRAILING_LABEL_RE = re.compile(
    r"\b(?:"
    r"date\s*of\s*birth|d\.?\s*o\.?\s*b\.?|year\s*of\s*birth|y\.?\s*o\.?\s*b\.?|"
    r"date\s*of\s*issue|"
    r"male|female|transgender|"
    r"father|husband|mother|wife|guardian|"
    r"s/o|d/o|w/o|c/o|"
    r"address|government\s*of\s*india|জন্ম\s*তারিখ|জন্ম\s*সাল"
    r")\b",
    re.IGNORECASE,
)


def _strip_trailing_labels(name: str) -> str:
    """Cut a captured name at the first field-label keyword that bleeds in.

    Defends against OCR runs where the name and the following field label end up
    on the same line, so the greedy name capture swallows e.g. "Date Of Birth".
    """
    m = _TRAILING_LABEL_RE.search(name)
    if m:
        name = name[: m.start()]
    return re.sub(r"\s+", " ", name).strip(" .,-")


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
            candidate = _strip_trailing_labels(m.group(1)).title()
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
            # Remove trailing field-label bleed and collapse whitespace.
            candidate = _strip_trailing_labels(m.group(1))
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
