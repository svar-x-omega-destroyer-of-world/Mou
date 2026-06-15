# CLAUDE.md — Mou builder manual

You are building **Mou**: an AI tool that tells a PDS/ONORC beneficiary **why**
they were silently cut off from their rations, and aggregates cases so officials
see systemic defects. Hackathon build, window June 14–21 2026.

**Read these files before working. They override your assumptions:**
- `docs/srs_digest.md` — what to build + the FR-1..FR-20 requirement IDs (short).
- `contract/openapi.yaml` — the API shape. NEVER deviate from it.
- `docs/rules_spec.md` — the root-cause rules + matching. Implement EXACTLY.
- `docs/build_plan.md` — the ordered task cards. Do one at a time.

The **full, authoritative** spec is `docs/Mou_SRS_v2.md` (it ships inside this
repo — you never need it provided separately). The digest is the fast reference;
if the digest and the full SRS disagree, the full SRS wins.

---

## Architecture in one picture

```
   Flutter app  ─┐                          ┌─ writes anonymised events
   (citizen)     ├─► FastAPI backend ─────► │   SQLite event store
   Next.js dash ─┘   (single source of      └─ computes clusters once
   (officials, read-only)  truth)
```
One backend, two clients, one locked JSON contract. The two frontends never talk
to each other. The dashboard is **read-only**. (SRS §3)

---

## Invariants — NEVER violate these (re-read before every backend change)

1. **No LLM decides anything.** Root cause is chosen by deterministic Python
   rules in `backend/app/rules.py`. The LLM (Gemini) only rephrases the
   explanation text. (FR-7, FR-18)
2. **Never assert eligibility.** Output is always "likely / may". Never "you
   qualify" or "you don't qualify". (FR-10)
3. **Never write to or modify any government record.** Mou only reads the user's
   own documents. (FR-17)
4. **The explanation must always work offline.** If Gemini fails, fall back to a
   pre-written local string. A network failure must never break `/diagnose`. (FR-11, Risk R-4)
5. **No real personal data is persisted.** Stored events are anonymised:
   `{root_cause, fps_location, document_pattern}` only — no names, no Aadhaar
   numbers. (SRS §7)
6. **Don't change the contract** (`contract/openapi.yaml`) without being asked.
   Both frontends depend on it.

If a task seems to require breaking one of these, **STOP and ask.**

---

## Repo map

| Path | What | Tech |
|---|---|---|
| `contract/` | `openapi.yaml` + `mocks/*.json` — the locked contract | YAML/JSON |
| `backend/` | FastAPI service (mock now → real pipeline) | Python 3.13 |
| `app/` | Flutter citizen app (Firebase already wired) | Dart/Flutter |
| `dashboard/` | Next.js officials dashboard | TS/Next/Tailwind |
| `docs/` | SRS, build_plan, rules_spec | Markdown |

---

## Commands (copy-paste)

**Backend**
```bash
cd backend
python3 -m venv .venv
./.venv/bin/pip install -r requirements.txt
./.venv/bin/uvicorn app.main:app --reload      # http://localhost:8000  (/docs for Swagger)
./.venv/bin/pip install pytest && ./.venv/bin/python -m pytest -q    # run tests
```

**Dashboard**
```bash
cd dashboard && npm install && npm run dev      # http://localhost:3000
```

**App**
```bash
cd app && flutter pub get && flutter run
```

---

## Definition of done (every task)
- The acceptance test in the task card passes.
- No invariant above is violated.
- Response shapes still match `contract/openapi.yaml`.
- You did not touch unrelated files.

## What NOT to do
- Don't redesign the rules or thresholds — they're fixed in `rules_spec.md`.
- Don't add root causes beyond the 6 + fallback.
- Don't put an LLM call on the classification path.
- Don't store names/Aadhaar numbers anywhere.
- Don't refactor the contract or rename API fields.
- Don't skip the OCR spike (Task 1.1) — it's the #1 risk.

## Tech stack (all free-tier, per SRS §4)
OCR: Google Cloud Vision via REST + Mou's own API key (fallback Tesseract ben+eng) · Matching:
indic-transliteration + rapidfuzz · Explanation: Gemini + local fallbacks ·
Store: SQLite/Postgres · Deploy: backend on Render/Railway, dashboard on Vercel,
app as APK.
