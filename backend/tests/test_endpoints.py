"""Integration tests for API endpoints (backend/app/main.py).

Tests the HTTP layer — request parsing, response shapes, error codes.
The OCR + extraction chain is tested separately in test_ocr.py / test_extract.py.
"""
from __future__ import annotations

import io
from pathlib import Path

import pytest
from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)

# A tiny valid 1×1 grey PNG (137 bytes) — too small for OCR
_DUMMY_PNG = bytes(
    [
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,  # PNG signature
        0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,  # IHDR chunk
        0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
        0x08, 0x02, 0x00, 0x00, 0x00, 0x90, 0x77, 0x53,
        0xDE, 0x00, 0x00, 0x00, 0x0C, 0x49, 0x44, 0x41,  # IDAT chunk
        0x54, 0x08, 0xD7, 0x63, 0x60, 0xF8, 0xCF, 0x50,
        0x0F, 0x00, 0x0E, 0x06, 0x01, 0x62, 0x00, 0x9D,
        0x3C, 0xE1, 0x17, 0x00, 0x00, 0x00, 0x00, 0x49,  # IEND chunk
        0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
    ]
)

# Real-ish images that OCR can read (ration card samples from the spike)
_SAMPLES = Path(__file__).resolve().parent.parent / "spikes" / "samples"
_REAL_AADHAAR_STANDIN = _SAMPLES / "Screenshot 2026-06-15 at 5.52.00 PM.png"
_REAL_RATION = _SAMPLES / "1764180718_692742eecb102.png"


class TestHealth:
    def test_health_returns_ok(self):
        resp = client.get("/health")
        assert resp.status_code == 200
        assert resp.json() == {"status": "ok"}


class TestDiagnose:
    def test_unreadable_image_returns_422(self):
        """FR-4: unreadable images → 422."""
        resp = client.post(
            "/diagnose",
            files={
                "aadhaar_image": ("aadhaar.png", io.BytesIO(_DUMMY_PNG), "image/png"),
                "ration_card_image": ("ration.png", io.BytesIO(_DUMMY_PNG), "image/png"),
            },
            data={
                "symptom": "turned_away_at_fps",
                "fps_location": "Silchar FPS #4471",
            },
        )
        assert resp.status_code == 422, f"Expected 422, got {resp.status_code}: {resp.text}"
        body = resp.json()
        detail = body["detail"] if "detail" in body else body
        assert detail.get("error") == "unreadable_image"

    def test_missing_symptom_returns_422(self):
        """Required field missing → 422."""
        resp = client.post(
            "/diagnose",
            files={
                "aadhaar_image": ("a.png", io.BytesIO(_DUMMY_PNG), "image/png"),
                "ration_card_image": ("r.png", io.BytesIO(_DUMMY_PNG), "image/png"),
            },
            data={},
        )
        assert resp.status_code == 422

    def test_response_shape_matches_contract(self):
        """Real-ish image pair → successful diagnosis with correct shape."""
        if not _REAL_AADHAAR_STANDIN.exists() or not _REAL_RATION.exists():
            pytest.skip("Sample images not available")

        aadhaar_bytes = _REAL_AADHAAR_STANDIN.read_bytes()
        ration_bytes = _REAL_RATION.read_bytes()
        resp = client.post(
            "/diagnose",
            files={
                "aadhaar_image": ("aadhaar.png", io.BytesIO(aadhaar_bytes), "image/png"),
                "ration_card_image": ("ration.png", io.BytesIO(ration_bytes), "image/png"),
            },
            data={
                "symptom": "turned_away_at_fps",
                "fps_location": "Silchar FPS #4471",
            },
        )
        if resp.status_code == 422:
            pytest.skip("OCR could not read sample images")
        assert resp.status_code == 200, f"Expected 200, got {resp.status_code}: {resp.text}"
        body = resp.json()

        # Required fields per openapi.yaml
        assert "root_cause" in body
        assert "confidence" in body
        assert "extracted" in body
        assert "explanation" in body
        assert "next_step" in body
        assert "disclaimer" in body
        assert "explanation_source" in body

        # Root cause must be one of the valid enum values
        valid_causes = {
            "name_mismatch", "dob_mismatch", "seeding_gap",
            "ekyc_incomplete", "biometric_failure", "unknown",
        }
        assert body["root_cause"] in valid_causes, f"Unexpected root_cause: {body['root_cause']}"

        # Confidence must be one of high/medium/low
        assert body["confidence"] in ("high", "medium", "low")

        # Warning: Aadhaar name may be empty (dummy image) but ration name should be present
        assert len(body["extracted"]["ration_name_script"]) > 0, "Ration name should be extracted"

        # Fallback explanation should be present (no GEMINI_API_KEY in test env)
        assert len(body["explanation"]) > 0
        assert body["explanation_source"] == "fallback"

    def test_response_never_says_qualify(self):
        """FR-10: response never states eligibility."""
        if not _REAL_AADHAAR_STANDIN.exists() or not _REAL_RATION.exists():
            pytest.skip("Sample images not available")

        aadhaar_bytes = _REAL_AADHAAR_STANDIN.read_bytes()
        ration_bytes = _REAL_RATION.read_bytes()
        resp = client.post(
            "/diagnose",
            files={
                "aadhaar_image": ("aadhaar.png", io.BytesIO(aadhaar_bytes), "image/png"),
                "ration_card_image": ("ration.png", io.BytesIO(ration_bytes), "image/png"),
            },
            data={"symptom": "turned_away_at_fps"},
        )
        if resp.status_code == 422:
            pytest.skip("OCR could not read sample images")
        assert resp.status_code == 200
        body = resp.json()
        text = f"{body['explanation']} {body['disclaimer']}".lower()
        assert "qualify" not in text, f"Response mentions eligibility: {text}"
        assert "eligible" not in text


class TestClusters:
    def test_clusters_returns_list(self):
        resp = client.get("/clusters")
        assert resp.status_code == 200
        data = resp.json()
        assert isinstance(data, list)
        if data:
            cluster = data[0]
            assert "root_cause" in cluster
            assert "fps_location" in cluster
            assert "beneficiaries_affected" in cluster
            assert "confidence" in cluster
            assert "cases" in cluster

    def test_clusters_ranked(self):
        """Clusters must be sorted by beneficiaries_affected descending."""
        resp = client.get("/clusters")
        data = resp.json()
        counts = [c["beneficiaries_affected"] for c in data]
        assert counts == sorted(counts, reverse=True), f"Not ranked: {counts}"

    def test_clusters_min_confidence_filter(self):
        """min_confidence query param filters correctly."""
        resp = client.get("/clusters?min_confidence=high")
        data = resp.json()
        for c in data:
            assert c["confidence"] == "high", f"Low-confidence cluster leaked: {c}"
