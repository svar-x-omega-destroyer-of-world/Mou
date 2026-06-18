"""Unit tests for the OCR readability gate (backend/app/ocr.py, FR-4).

Focus: the quality gate must reject genuinely unreadable (blurry → near-empty)
reads, but must NOT false-positive on clear, legible photos that happen to
return a short Vision read (sparse / tightly-cropped / slightly off-angle, or
English-dominant documents).
"""
from __future__ import annotations

import pytest

from app import ocr
from app.ocr import UnreadableImageError, extract_text

_DUMMY_BYTES = b"not-a-real-image-bytes"


@pytest.fixture(autouse=True)
def _with_api_key(monkeypatch):
    """Force the Vision branch (extract_text only calls Vision if a key exists)."""
    monkeypatch.setenv(ocr.ENV_KEY_NAME, "test-key")


def _patch_vision(monkeypatch, returned_text: str):
    monkeypatch.setattr(ocr, "ocr_google", lambda image_bytes, api_key: returned_text)


def test_short_legible_latin_read_is_accepted(monkeypatch):
    """Regression: a clear photo with a 20-39 char, <5-Bengali Vision read.

    This is the exact false-positive case — legible but short/off-angle —
    that the old `len(text) >= 40` secondary gate wrongly rejected.
    """
    # 31 chars, zero Bengali → previously rejected, now must pass.
    text = "Rahima Begum\nDOB 01/01/1980"
    assert len(text) < 40
    _patch_vision(monkeypatch, text)
    assert extract_text(_DUMMY_BYTES) == text.strip()


def test_short_bengali_read_is_accepted(monkeypatch):
    """A legible Bengali-dominant short read is also accepted."""
    text = "রহিমা বেগম\nসিলচর জেলা ৪৪৭১"  # short, but clearly real text (≥20 chars)
    _patch_vision(monkeypatch, text)
    assert extract_text(_DUMMY_BYTES) == text.strip()


def test_full_length_read_still_accepted(monkeypatch):
    """A normal full-length Aadhaar/ration read keeps working."""
    text = "Government of India\nRahima Begum\nDOB: 01/01/1980\nID 1234 5678 9012"
    _patch_vision(monkeypatch, text)
    assert extract_text(_DUMMY_BYTES) == text.strip()


def test_blurry_near_empty_read_still_rejected(monkeypatch):
    """A genuinely unreadable (blurry) photo yields little text → 422 path."""
    _patch_vision(monkeypatch, "a\n")  # below MIN_TEXT_LENGTH
    with pytest.raises(UnreadableImageError):
        extract_text(_DUMMY_BYTES)


def test_empty_read_still_rejected(monkeypatch):
    """No extractable text at all → unreadable."""
    _patch_vision(monkeypatch, "")
    with pytest.raises(UnreadableImageError):
        extract_text(_DUMMY_BYTES)
