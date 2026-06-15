#!/usr/bin/env python3
"""Seed the event store with ~100 synthetic anonymised events (SRS §11.2).

Usage:
    cd backend && ./.venv/bin/python seed.py

After seeding, GET /clusters returns the same structure as the day-1 mock,
with the Silchar name_mismatch cluster at ~40 beneficiaries and ranked first.
"""
from __future__ import annotations

import random
import sys
from pathlib import Path

# Ensure ``app`` is importable when run directly from backend/
sys.path.insert(0, str(Path(__file__).resolve().parent))

from app.events import record_event, reset_db
from app.schemas import Confidence, RootCause

# ── Synthetic data pool ─────────────────────────────────────────────────────

LOCATIONS = [
    "Silchar FPS #4471",
    "Karimganj FPS #2210",
    "Hailakandi FPS #1180",
    "Cachar FPS #3315",
    "Barak Valley FPS #0021",
]

NAME_PATTERNS = [
    "Begum/Begam",
    "Khatun/Khatoon",
    "Rahman/Rehman",
    "Hussain/ Hossen",
    "Mondal/Mandal",
    "Sheikh/Shaikh",
]

SEED_CONFIG: list[dict] = [
    # --- Silchar name_mismatch cluster (largest, ~40) ---
    *[  # 20 x Begum/Begam
        {"cause": RootCause.name_mismatch, "loc": LOCATIONS[0],
         "pat": NAME_PATTERNS[0], "conf": Confidence.medium}
        for _ in range(20)
    ],
    *[  # 12 x Khatun/Khatoon
        {"cause": RootCause.name_mismatch, "loc": LOCATIONS[0],
         "pat": NAME_PATTERNS[1], "conf": Confidence.medium}
        for _ in range(12)
    ],
    *[  # 8 x Rahman/Rehman
        {"cause": RootCause.name_mismatch, "loc": LOCATIONS[0],
         "pat": NAME_PATTERNS[2], "conf": Confidence.high}
        for _ in range(8)
    ],
    # --- Karimganj seeding_gap (27) ---
    *[
        {"cause": RootCause.seeding_gap, "loc": LOCATIONS[1],
         "pat": "aadhaar_not_seeded", "conf": Confidence.high}
        for _ in range(27)
    ],
    # --- Hailakandi biometric_failure (14) ---
    *[
        {"cause": RootCause.biometric_failure, "loc": LOCATIONS[2],
         "pat": "fingerprint_worn", "conf": Confidence.medium}
        for _ in range(14)
    ],
    # --- Silchar dob_mismatch (6) ---
    *[
        {"cause": RootCause.dob_mismatch, "loc": LOCATIONS[0],
         "pat": random.choice(["1989/1998", "1975/1980", "1992/1995"]),
         "conf": Confidence.low}
        for _ in range(6)
    ],
    # --- Cachar name_mismatch (5) ---
    *[
        {"cause": RootCause.name_mismatch, "loc": LOCATIONS[3],
         "pat": random.choice(NAME_PATTERNS), "conf": Confidence.medium}
        for _ in range(5)
    ],
    # --- Barak Valley seeding_gap (4) ---
    *[
        {"cause": RootCause.seeding_gap, "loc": LOCATIONS[4],
         "pat": "aadhaar_not_seeded", "conf": Confidence.medium}
        for _ in range(4)
    ],
    # --- Hailakandi ekyc_incomplete (3) ---
    *[
        {"cause": RootCause.ekyc_incomplete, "loc": LOCATIONS[2],
         "pat": "ekyc_incomplete", "conf": Confidence.low}
        for _ in range(3)
    ],
    # --- A few unknown / other (2) ---
    *[
        {"cause": RootCause.unknown, "loc": LOCATIONS[0],
         "pat": "unknown", "conf": Confidence.low}
        for _ in range(2)
    ],
]

# ~101 total


def main() -> int:
    reset_db()
    count = 0
    for cfg in SEED_CONFIG:
        record_event(
            root_cause=cfg["cause"],
            confidence=cfg["conf"],
            fps_location=cfg["loc"],
            document_pattern=cfg["pat"],
        )
        count += 1

    print(f"Seeded {count} anonymised events.")
    print()
    print("Expected clusters (top 3):")
    print(f"  1. name_mismatch @ Silchar FPS #4471  ~40 beneficiaries")
    print(f"  2. seeding_gap   @ Karimganj FPS #2210  ~27 beneficiaries")
    print(f"  3. biometric_failure @ Hailakandi FPS #1180  ~14 beneficiaries")
    return 0


if __name__ == "__main__":
    sys.exit(main())
