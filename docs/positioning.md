# Mou — Positioning & Pitch (canonical narrative)

> Single source for the README and the deck. This is the STORY layer.
> It does **not** change build scope: the build implements one scheme (PDS/ONORC).
> See `CLAUDE.md` §Scope guard.

## One-liner
Mou diagnoses **why someone was silently excluded from a government benefit** — when the
cause is a name / date-of-birth / address mismatch across their own documents — explains
it in plain language, gives one concrete next step, and aggregates cases so officials see
the systemic defect. (USAII Direction A — *Benefits Navigator*.)

## The problem (general)
Millions of eligible Indians are quietly dropped from welfare schemes — pensions,
scholarships, subsidies, rations — not because they're ineligible, but because a field
doesn't match across Aadhaar and the scheme's record (often across scripts, e.g. Bengali
vs English). No notice is sent. They learn only when turned away. The defect is the same
everywhere: **a document mismatch silently denies a real entitlement.**

## Why it wins (two pillars)
1. **Systemic visibility (the inversion).** One rejection is a personal misfortune. Many
   rejections sharing one root cause at one location is an *accountability report* — and
   Mou is what makes it visible.
2. **Generality.** Mou is a *silent-exclusion engine*, not a ration app. The same pipeline
   — OCR → extract name/DOB/address → cross-document match → deterministic mismatch rule →
   plain-language explanation → clustering — applies to any scheme.

## What we prove live (the flagship)
PDS/ONORC food rations, Bengali ration card + English Aadhaar. Chosen because it carries
every hard part: cross-script OCR, real beneficiaries, and a systemic-clustering story.
Golden path: **Rahima Begum** — English Aadhaar + Bengali ration card → name mismatch →
"you are one of many" dashboard zoom-out. **The demo exercises the proxy path at least
once** (FR-2, must-have): the flow opens on the explicit self-serve vs. "filing on someone
else's behalf" choice, and the walkthrough files *as a caregiver/CSC operator on Rahima's
behalf* — because the product is built for low-digital-literacy beneficiaries reached via a
caregiver / CSC operator / family member, not assuming the excluded person owns a smartphone.

## The generality proof in the demo (mockup only — NOT built)
One slide: the identical flow on a **second scheme** (e.g. a pension or scholarship) where
the same name mismatch silently excludes someone. A visual mockup that reuses the real UI —
no code, no second pipeline. Its job is to make "any scheme" credible by showing the engine
is indifferent to which document it reads.

## Roadmap — making "multipurpose" real (POST-Jun 21, not now)
> Decision (2026-06-18): objective = **win the hackathon first**. Build stays ration-only
> through the demo; the generality claim is carried by the mockup above. The refactor below
> is the *first task of the bigger project*, AFTER the window closes. Do NOT start it pre-demo.

**Diagnosis (already done, so this starts warm).** The *engine* is already scheme-agnostic —
`ocr.py`, `matching.py`, `events.py`/clustering don't know what a ration is. But a *scheme*
is not yet **data**; it's hardcoded across three layers with no seam:
- **Contract:** `/diagnose` form fields `aadhaar_image` / `ration_card_image` (two docs, named).
- **Schemas:** `Extracted` fields `aadhaar_name` / `ration_name_script` / `ration_dob` — doc
  types baked into field *names*; `RootCause` / `Symptom` are closed ration enums.
- **Logic:** `extract.py` (two hand-written extractors), `rules.py`, `_NEXT_STEPS`,
  `_document_pattern` — all ration-cause tables.

**The one move (behavior-preserving, tests must stay 46/46):** introduce a `Scheme`
descriptor — `{documents + extractors, root-cause list + rule cascade, next-step map,
explanation templates}` — and make ration **instance #1**. Generalize
`aadhaar_name`/`ration_name` → `doc_a`/`doc_b` (or a document list). Only *then* add a real
scheme #2. Adding schemes before this seam exists is the abstraction-addiction trap — don't.

## Boundaries (say these out loud)
Mou flags; humans decide. It does not adjudicate eligibility, edit any government record,
give legal/medical advice, or guarantee outcomes. No real PII is stored; events are
anonymised.
