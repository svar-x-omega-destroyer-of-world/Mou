# Mou — Root-Cause Rules & Matching Spec

> **Read this before writing any code in `backend/app/rules.py` or `backend/app/matching.py`.**
> This is the reasoning-hard core (SRS §4.2 reserves it for the strong model).
> It is already designed. **Your job is to implement it exactly, not to redesign it.**
> Do not add rules, remove rules, or change thresholds without being asked.

---

## 0. Why this exists

A legitimate beneficiary is silently cut off from rations. The cause is one of a
small, known set of backend defects. We must pick **exactly one primary root
cause** (FR-7) using **deterministic rules only** — no LLM, ever, on this path
(FR-18). The LLM only rephrases the explanation afterward.

There are exactly **6 root causes + 1 fallback**. Do not invent more.

| `root_cause` value   | Real-world meaning                                              |
|----------------------|----------------------------------------------------------------|
| `name_mismatch`      | Name spelled differently across Aadhaar vs ration card. Blocks auto-matching. **This is the flagship case.** |
| `dob_mismatch`       | Date of birth differs across the two documents.                |
| `seeding_gap`        | Aadhaar not seeded/linked to the ration card → ONORC portability fails. |
| `ekyc_incomplete`    | e-KYC not finished → entitlement held.                         |
| `biometric_failure`  | Repeated fingerprint/iris auth failure (worn prints, elderly). |
| `unknown`            | No rule fired confidently → hand to a human (HITL).            |

---

## 1. Inputs to the rule engine

After OCR + matching, the rule engine receives this exact structure. Build it
first; the rules read only these fields.

```python
@dataclass
class RuleInput:
    name_score: int          # 0-100 transliteration-aware similarity (see §3)
    dob_status: str          # "match" | "mismatch" | "unknown"
    symptom: str             # one of the Symptom enum values (intake)
```

`symptom` is one of: `turned_away_at_fps`, `card_not_found`,
`biometric_failed`, `name_not_matching`, `other`.

---

## 2. The rule cascade (implement EXACTLY in this order)

**First matching rule wins.** Evaluate top to bottom. Stop at the first hit.
This ordering is deliberate — do not reorder.

```
RULE 1  — biometric failure (hard symptom, documents are irrelevant)
  IF symptom == "biometric_failed":
      return (biometric_failure, HIGH)

RULE 2  — name mismatch (the flagship; objective document evidence)
  IF name_score < 85:
      IF name_score < 70:
          conf = HIGH
      ELSE:                         # 70..84  -> transliteration-level variance
          conf = MEDIUM
      IF symptom == "name_not_matching":
          conf = HIGH               # user corroborates -> upgrade
      return (name_mismatch, conf)

RULE 3  — date-of-birth mismatch
  IF dob_status == "mismatch":
      conf = HIGH if name_score >= 85 else MEDIUM
      return (dob_mismatch, conf)

RULE 4  — seeding gap (docs are clean, but card not found at shop)
  IF symptom == "card_not_found":
      return (seeding_gap, MEDIUM)

RULE 5  — e-KYC incomplete (docs are clean, turned away)
  IF symptom == "turned_away_at_fps":
      return (ekyc_incomplete, LOW)

RULE 6 / FALLBACK — nothing fired confidently
  return (unknown, LOW)
```

That is **5 firing rules + 1 fallback = 6 paths**. Within SRS "5–7 rules".

### Worked examples (use these as unit tests — see §5)

| name_score | dob_status | symptom              | → root_cause       | confidence |
|-----------:|------------|----------------------|--------------------|------------|
| 78         | match      | turned_away_at_fps   | `name_mismatch`    | medium     |
| 78         | match      | name_not_matching    | `name_mismatch`    | high       |
| 55         | unknown    | turned_away_at_fps   | `name_mismatch`    | high       |
| 95         | mismatch   | turned_away_at_fps   | `dob_mismatch`     | high       |
| 80         | mismatch   | other                | `name_mismatch`    | medium     | (RULE 2 fires before RULE 3 — name first)
| 96         | match      | biometric_failed     | `biometric_failure`| high       | (RULE 1 short-circuits)
| 96         | match      | card_not_found       | `seeding_gap`      | medium     |
| 96         | match      | turned_away_at_fps   | `ekyc_incomplete`  | low        |
| 96         | match      | other                | `unknown`          | low        |

> Note row 5: even with a DOB mismatch, RULE 2 fires first because the name
> score is below 85. That is intended — do not "fix" it.

---

## 3. Transliteration-aware name matching (`name_score`)

**Problem:** Aadhaar name is in Latin ("Rahima Begum"); ration card name is in
Bengali script ("রহিমা বেগম"). We must score how similar they are despite the
script difference. The flagship case is **Begum vs Begam** — these must come out
as *similar but not identical* (score in the 70–84 band → `name_mismatch`,
medium confidence).

### Pipeline (implement each step)

```
1. ROMANISE the Bengali name to Latin.
     Use indic-transliteration (sanscript): Bengali -> ITRANS (or HK).
     রহিমা বেগম  ->  e.g. "rahimaa begama"

2. NORMALISE both strings (the Aadhaar Latin name AND the romanised one):
     - lowercase
     - strip leading/trailing whitespace, collapse internal whitespace
     - remove punctuation/dots
     - drop a trailing inherent 'a' on each token  (begama -> begam, rahimaa -> rahima)
     - remove common honorifics/titles as standalone tokens:
         {"md", "mohd", "mohammed", "muhammad", "sri", "smt", "kumari", "begum"? NO}
       (do NOT strip "begum"/"begam" — that token IS the signal here)

3. SCORE with rapidfuzz:
     name_score = rapidfuzz.fuzz.token_sort_ratio(norm_aadhaar, norm_ration)
     (round to int 0-100)
```

### Expected outputs (use as unit tests)

| Aadhaar      | Ration (script) | romanised+normalised | expected band      |
|--------------|-----------------|----------------------|--------------------|
| Rahima Begum | রহিমা বেগম      | rahima begam         | 70–84 → mismatch/medium |
| Rahima Begum | রহিমা বেগম + same spelling | rahima begum | ≥85 → no mismatch  |
| Anil Kumar   | অনিল কুমার      | anil kumar           | ≥85 → no mismatch  |
| Fatima Khatun| ফাতিমা খাতুন    | fatima khatun        | ≥85 → no mismatch  |

> Tune nothing else. If "Begum vs Begam" does not land in 70–84, fix the
> **normalisation** (step 2), not the thresholds in §2. Add a failing test
> first, then make it pass.

### Library notes (so you don't guess)
- `pip install indic-transliteration rapidfuzz`
- ```python
  from indic_transliteration import sanscript
  from indic_transliteration.sanscript import transliterate
  roman = transliterate("রহিমা বেগম", sanscript.BENGALI, sanscript.ITRANS)
  ```
- `rapidfuzz.fuzz.token_sort_ratio` handles word-order differences; good default.

---

## 4. OCR (Risk R-1 — the dominant risk)

**Do this on Day 1 before writing matching code.** Garbage OCR makes perfect
matching useless.

- Primary: Google Cloud Vision API (`google-cloud-vision`), free tier.
- Fallback: Tesseract with Bengali (`ben`) + English (`eng`) traineddata.
- Preprocess phone photos: auto-crop, grayscale, increase contrast before OCR.
- Acceptance: feed 3 real phone photos of a Bengali ration card; the name
  region must come out readable enough that §3 produces the expected bands.
- Worst case (documented fallback, SRS R-1): demo on one curated high-quality
  document pair and frame OCR as the demonstrated concept.

The diagnosis engine must degrade gracefully: if OCR confidence is too low,
return HTTP 422 with `{"error":"unreadable_image", ...}` (FR-4) — never guess.

---

## 5. How to verify your implementation

Put the §2 table in `backend/tests/test_rules.py` and the §3 table in
`backend/tests/test_matching.py`, one assertion per row. Then:

```bash
cd backend && ./.venv/bin/pip install pytest && ./.venv/bin/python -m pytest -q
```

**Definition of done for the rules:** every row in the §2 and §3 tables passes.
Do not move on until they do.

---

## 6. Hard invariants (never violate — re-read before each change)

1. **No LLM on the classification path.** Rules are pure Python. (FR-18)
2. **Output is always "likely".** Never assert the person is eligible/ineligible. (FR-10)
3. **Never write to or modify any government record.** Mou only reads documents. (FR-17)
4. **Exactly one primary root cause** per diagnosis. (FR-7)
5. When unsure, return `unknown` + low confidence — that routes to a human. Never force a guess.
