"""Transliteration-aware name matching + DOB status (rules_spec.md §3).

Pipeline for a single diagnosis:
  1. romanise()     — Bengali script → ITRANS Latin (indic-transliteration)
  2. normalise()    — lowercase, strip, collapse, remove punct, apply ITRANS→English
                     character mappings (v→b, ph→f, kh→k, A→a), then drop
                     trailing inherent 'a' from Aadhaar tokens only.
  3. name_score()   — rapidfuzz token_sort_ratio on the two normalised strings.
  4. dob_status()   — "match" | "mismatch" | "unknown" between two DOB strings.

The critical flaghsip case is Begum vs Begam (Bengali বেগম → ITRANS 'vegama'
→ normalised 'begama').  After normalisation an English "Rahima Begum" scores
70-84 against it, landing in the name_mismatch/medium band.  Tune the
normalisation (not thresholds) if this stops being true.
"""
from __future__ import annotations

import re
from typing import Optional

from indic_transliteration import sanscript
from indic_transliteration.sanscript import transliterate
from rapidfuzz import fuzz

# ---------------------------------------------------------------------------
# ITRANS → English character mappings
# ---------------------------------------------------------------------------
# Bengali ব is mapped to 'v' by ITRANS (Sanskrit-centric scheme), but it is
# pronounced /b/ in modern Bengali.  Similarly ফ is /f/ and খ is /k/.
# A is the ITRANS long-vowel marker (ā).
_ITRANS_SUBS = str.maketrans({
    "A": "a",  # ITRANS long-vowel ā → plain a
    "v": "b",  # ব (ba) → b
    # 'ph' and 'kh' are multi-char, handled via str.replace below
})

# Hindi/Urdu-style honorifics that appear as standalone tokens in names.
# We strip them so they don't distort the similarity score.
# NOT in this set: begum, begam, khatun, bibi — those are name tokens (the signal).
_HONORIFICS = frozenset({
    "md", "mohd", "mohammed", "muhammad",
    "sri", "smt", "shri", "shrimati",
    "kumari", "suresh", "ramesh",  # common first-name tokens in some regions
})


def romanise(bengali: str) -> str:
    """Transliterate a Bengali string to Latin (ITRANS scheme).

    Args:
        bengali: Text in Bengali script (Unicode 0x0980-0x09FF).

    Returns:
        ITRANS romanisation, e.g. "রহিমা বেগম" → "rahimA vegama".
    """
    return transliterate(bengali, sanscript.BENGALI, sanscript.ITRANS)


def normalise(name: str, *, drop_trailing_a: bool = True) -> str:
    """Normalise a person-name string for fuzzy comparison.

    Steps (rules_spec.md §3):
      1. Lowercase.
      2. Strip leading/trailing whitespace; collapse internal whitespace.
      3. Remove punctuation and non-word characters.
      4. Apply ITRANS→English character mappings (A→a, v→b, ph→f, kh→k).
      5. Optionally drop a trailing inherent 'a' from each token
         (use ``drop_trailing_a=True`` for the Aadhaar/English name to
          offset the inherent vowel that ITRANS appends to consonants).
      6. Strip known honorifics.

    Args:
        name: A person name string (Latin script, or the output of romanise()).
        drop_trailing_a:
            True → remove trailing 'a' from each token (for the Aadhaar side).
            False → keep trailing 'a' (for the romanised ration side).

    Returns:
        Clean, single-space-joined string ready for fuzzy scoring.
    """
    # 1-3. Lowercase, strip, collapse spaces, remove punctuation.
    s = name.lower().strip()
    s = re.sub(r"\s+", " ", s)
    s = re.sub(r"[^\w\s]", "", s)

    # 4. ITRANS → English character mappings.
    s = s.replace("ph", "f")
    s = s.replace("kh", "k")
    s = s.translate(_ITRANS_SUBS)  # A→a, v→b

    # 5. Drop trailing inherent 'a' (begama → begam).
    if drop_trailing_a:
        tokens = s.split()
        cleaned = []
        for t in tokens:
            if t.endswith("a") and len(t) > 1:
                t = t[:-1]
            cleaned.append(t)
        s = " ".join(cleaned)

    # 6. Remove known honorifics.
    tokens = s.split()
    tokens = [t for t in tokens if t not in _HONORIFICS]
    s = " ".join(tokens)

    return s


def name_score(aadhaar: str, ration_script: str) -> int:
    """Transliteration-aware similarity between an Aadhaar and ration name.

    Args:
        aadhaar: Latin-script name from the Aadhaar card.
        ration_script: Bengali-script name from the ration card.

    Returns:
        Integer 0-100 (higher = more similar).  Threshold bands used by the
        rule engine:
          ≥85  — names effectively match (no mismatch detected).
          70–84 — transliteration-level variance (Begum/Begam, etc.), flagged.
          <70  — genuine name difference.
    """
    # Romanise the Bengali ration name to Latin.
    romanised = romanise(ration_script)

    # Normalise Aadhaar name WITH trailing-'a' drop (offset for inherent vowel).
    norm_a = normalise(aadhaar, drop_trailing_a=True)

    # Normalise romanised ration name WITHOUT trailing-'a' drop
    # (the inherent vowel is part of the ITRANS output and should remain).
    norm_r = normalise(romanised, drop_trailing_a=False)

    return int(round(fuzz.token_sort_ratio(norm_a, norm_r)))


def dob_status(aadhaar_dob: Optional[str], ration_dob: Optional[str]) -> str:
    """Compare two date-of-birth values.

    Returns:
        "match"    — both present and identical.
        "mismatch" — both present but differ.
        "unknown"  — either or both absent.
    """
    if aadhaar_dob is None or ration_dob is None:
        return "unknown"

    # Normalise separators
    a = re.sub(r"[ \-/]", "-", aadhaar_dob.strip())
    r = re.sub(r"[ \-/]", "-", ration_dob.strip())

    if a == r:
        return "match"
    return "mismatch"
