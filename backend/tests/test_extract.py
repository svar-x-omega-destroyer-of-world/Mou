"""Unit tests for field extraction (backend/app/extract.py).

Focus: the name capture must not absorb the *next* field's label when OCR drops
the newline between the name and the field below it.  This caused a false
"Name Mismatch" diagnosis when an Aadhaar name extracted as
"Dino Saren Date Of Birth" was compared against ration "DINO SAREN".
"""
from __future__ import annotations

import pytest

from app.extract import extract_aadhaar, extract_ration
from app.matching import name_score


class TestNameLabelBleed:
    @pytest.mark.parametrize(
        "text",
        [
            "Name Dino Saren Date Of Birth 01/01/1990",      # newline dropped
            "Name: Dino Saren\nDate Of Birth: 01/01/1990",   # normal newline
            "नाम\nDino Saren\nDate Of Birth\n01/01/1990",     # Hindi label
            "Name Dino Saren Male 1234 5678 9012",           # gender label after
        ],
    )
    def test_aadhaar_name_stops_at_field_label(self, text):
        name, _ = extract_aadhaar(text)
        assert name == "Dino Saren"

    def test_ration_name_stops_at_field_label(self):
        name, _ = extract_ration(
            "Name of the Card Holder : DINO SAREN Date of Birth 01/01/1990"
        )
        assert name == "DINO SAREN"

    def test_plain_name_unaffected(self):
        """A name with no trailing label must pass through unchanged."""
        assert extract_aadhaar("Name Rahima Begum")[0] == "Rahima Begum"

    def test_bleed_no_longer_triggers_false_mismatch(self):
        """Regression: the bled name scored 59 (mismatch); the fix restores 100."""
        aadhaar_name, _ = extract_aadhaar("Name Dino Saren Date Of Birth 01/01/1990")
        assert name_score(aadhaar_name, "DINO SAREN") == 100
