# Mou — Build Plan (for DeepSeek Flash V4 via Claude Code)

> **How to use this:** Hand the builder model **one task card at a time**, in
> order. Each card is self-contained: goal, files, steps, and an acceptance test
> it must pass before moving on. Do not skip the acceptance test.
>
> **Always-loaded context for the builder:** `CLAUDE.md` (invariants + commands),
> `contract/openapi.yaml` (the API shape — never deviate), `docs/rules_spec.md`
> (the rules — implement exactly).

---

## Ground rules for every task

1. **The contract is law.** Request/response shapes come from
   `contract/openapi.yaml`. Never invent fields or change names.
2. **Run the acceptance test** in the card before declaring a task done.
3. **Don't refactor unrelated code.** One task, one concern.
4. **Re-read the invariants** in `CLAUDE.md` §Invariants before each backend task.
5. If a card is ambiguous, **stop and ask** — do not guess on the rules or contract.

---

## Repo layout (already created)

```
Mou/
├── contract/        openapi.yaml + mocks/   ← LOCKED day-1 source of truth
├── backend/         FastAPI (mock today → real pipeline)
├── app/             Flutter citizen app (Firebase already wired)
├── dashboard/       Next.js officials dashboard (to be created)
├── docs/            SRS, this plan, rules_spec.md
└── CLAUDE.md        builder operating manual
```

---

# PHASE 1 — De-risk + lock (Day 1–2)

### Task 1.0 — Place Mou's own Vision API key (HUMAN, do before 1.1)
**Goal:** Mou must have its **own** Google Cloud Vision access — separate from any
other project. The `~/Documents/ec` project is a read-only reference only; never use
its key.
- Confirm the **Cloud Vision API** is enabled on the project that issued Mou's
  **fresh Vision API key**, then put the key in `backend/spikes/.env` as
  `GOOGLE_VISION_API_KEY=...` (gitignored via `.env` / `.env.*`). No service-account
  JSON is needed — Task 1.1 calls Vision over REST with this key.
- Free tier: Vision gives 1,000 units/month free — plenty for the spike + demo.
**Acceptance:** `GOOGLE_VISION_API_KEY` is set in `backend/spikes/.env` (or exported)
and a Vision call from `backend/.venv` succeeds (the Task 1.1 spike is the real check).
**DoD:** Mou owns its OCR key; nothing references another project's key or credentials.

### Task 1.1 — OCR spike (Risk R-1, needs Task 1.0)
> **OCR provenance:** Mou's OCR is **ported from the team's own electoral pipeline**
> (`~/Documents/ec`) — copy its Vision call + language-hint + Bengali post-processing
> code into Mou (here for the spike, into `backend/app/ocr.py` for the Phase 2 real
> module). `ec` is never modified, run, or used for credentials; Mou uses its own key
> (Task 1.0). This is what "Mou builds its own OCR" means: own the code, our own creds.
> **Off-limits:** `~/Documents/ec/pre testing/` (note the space) — never open, read,
> run, or learn from anything inside it.

**Goal:** Prove the ported OCR reads a (multilingual) ration card photo before any
matching code exists.
- Create `backend/spikes/ocr_spike.py` that calls Vision over REST (with Mou's own
  `GOOGLE_VISION_API_KEY`) on the sample images in `backend/spikes/samples/` and
  prints the extracted text.
- No new dependency needed: the REST call uses `httpx`, already in `requirements.txt`.
**Acceptance:** running the spike prints readable Bengali text for the name
region of at least one real photo. If not, switch to Tesseract `ben+eng`
(document which in the file header) per `rules_spec.md` §4.
**DoD:** you can state, in one sentence, whether Vision is good enough or we use
the curated-pair fallback.

### Task 1.2 — Confirm the contract + mock backend run
**Goal:** Verify the locked contract and the existing mock backend.
- `cd backend && python3 -m venv .venv && ./.venv/bin/pip install -r requirements.txt`
- `./.venv/bin/uvicorn app.main:app --reload`
**Acceptance:** `GET /health` returns `{"status":"ok"}`; `GET /clusters` returns
the ranked list; Swagger UI at `/docs` shows `/diagnose` and `/clusters`.
**DoD:** both frontends now have a live mock URL to call.

### Task 1.3 — Dashboard skeleton + deploy
**Goal:** Create the Next.js dashboard and connect to the mock.
- `cd dashboard && npx create-next-app@latest . --ts --tailwind --app --no-src-dir`
- Add one page that fetches `GET http://localhost:8000/clusters` and renders the
  raw JSON in a table.
**Acceptance:** `npm run dev` shows the 4 mock clusters in a table.
**DoD:** deploy skeleton to Vercel; note the URL in `dashboard/README.md`.

### Task 1.4 — App connects to mock
**Goal:** Flutter app calls the mock `/diagnose`.
- Replace the "Firebase Connected" placeholder in `app/lib/main.dart` with a
  single screen that POSTs two dummy images to `/diagnose` and shows the JSON.
- Add `http` to `app/pubspec.yaml`.
**Acceptance:** running the app shows the Rahima Begum mock result.
**DoD:** app ↔ backend round-trip works against the mock.

---

# PHASE 2 — Diagnosis engine + citizen app (Day 3–4)

### Task 2.1 — Matching module
**Goal:** Implement `backend/app/matching.py` exactly per `rules_spec.md` §3.
- Functions: `romanise(bengali: str) -> str`, `normalise(name: str) -> str`,
  `name_score(aadhaar: str, ration_script: str) -> int`,
  `dob_status(aadhaar_dob, ration_dob) -> str`.
- Add `indic-transliteration`, `rapidfuzz` to `requirements.txt`.
**Acceptance:** `backend/tests/test_matching.py` (the §3 table) passes:
`./.venv/bin/python -m pytest backend/tests/test_matching.py -q`.
**DoD:** Begum/Begam lands in the 70–84 band.

### Task 2.2 — Rule engine
**Goal:** Implement `backend/app/rules.py` exactly per `rules_spec.md` §2.
- `classify(rule_input: RuleInput) -> tuple[RootCause, Confidence]` — the cascade,
  in order, first-match-wins.
**Acceptance:** `backend/tests/test_rules.py` (the §2 table) passes.
**DoD:** all 9 example rows green. No LLM imported anywhere in this file.

### Task 2.3 — Explanation layer + fallback
**Goal:** `backend/app/explain.py`: turn (root_cause, extracted) into plain text.
- Try Gemini (`google-generativeai`); on ANY error, return a pre-written local
  string keyed by `root_cause` from `backend/app/fallbacks.py`. (FR-11)
- Return `explanation_source` = `gemini` or `fallback` accordingly.
**Acceptance:** with no/blank API key, `/diagnose` still returns a full
explanation and `explanation_source == "fallback"`. (Simulates Risk R-4.)
**DoD:** pulling the network never 500s the endpoint.

### Task 2.4 — Wire the real pipeline into `/diagnose`
**Goal:** Replace the mock body of `POST /diagnose` with:
OCR → extract → `matching` → `rules.classify` → `explain` → response.
Keep the response shape identical to the contract.
**Acceptance:** posting the curated Rahima pair returns `name_mismatch` with the
two names in `extracted`; posting an unreadable image returns HTTP 422 (FR-4).
**DoD:** Swagger `/diagnose` works end-to-end on a real image pair.

### Task 2.5 — Flutter intake + verification UI
**Goal:** Build the real app flow (≤4 steps, low-literacy friendly, FR-1..4, FR-8).
- Screens: upload Aadhaar + ration → language + self/proxy toggle → symptom +
  FPS location → **side-by-side verification** (Aadhaar name vs ration name) →
  result with explanation + next step + disclaimer.
**Acceptance:** a person can complete the flow in ≤4 steps and see both names
side by side before the result. Disclaimer visible (FR-20).
**DoD:** demoable citizen flow against the live backend.

---

# PHASE 3 — Event store + dashboard (Day 5–6)

### Task 3.1 — Event store
**Goal:** `backend/app/events.py`: persist one anonymised event per diagnosis
`{root_cause, fps_location, document_pattern}` (FR-12). SQLite is fine.
**Acceptance:** each `/diagnose` call inserts exactly one row; no name/Aadhaar
number is stored (privacy by design, SRS §7).
**DoD:** events table fills as you diagnose.

### Task 3.2 — Clustering + real `/clusters`
**Goal:** Replace the mock `/clusters` body with a real groupby over the event
store: group by `(root_cause, fps_location)`, rank by distinct beneficiaries
(FR-13/14), drop below `min_confidence` (FR-16).
**Acceptance:** seed synthetic events (Task 3.3) → `/clusters` returns the same
shape as the mock, correctly ranked.
**DoD:** counts are computed once here (both clients show identical numbers).

### Task 3.3 — Synthetic seed data
**Goal:** `backend/seed.py` inserts ~100 synthetic anonymised events so the
dashboard looks real at scale (SRS §11.2). Reuse the patterns in
`contract/mocks/clusters.example.json`.
**Acceptance:** after seeding, the Silchar name_mismatch cluster shows ~40
beneficiaries and ranks first.
**DoD:** dashboard demo has volume.

### Task 3.4 — Dashboard real view
**Goal:** Replace raw-JSON table with the real UI: ranked clusters, each row
expandable to its anonymised cases (FR-15), confidence shown.
**Acceptance:** clicking a cluster reveals its `cases`; ordering matches the API.
**DoD:** read-only dashboard demoable.

---

# PHASE 4 — Resilience + Responsible-AI (Day 6–7)

### Task 4.1 — Responsible-AI surface
"Likely cause" framing everywhere; explicit disclaimer; flag-as-incorrect button
that logs feedback (FR-10/19/20). **Acceptance:** no screen ever says "you
qualify"; flag button writes a feedback record.

### Task 4.2 — Failure paths
Test: Gemini down → fallback fires; backend down → app shows graceful error +
offline shell; blurry image → re-upload prompt (FR-4). **Acceptance:** none of
these crash the app.

### Task 4.3 — Threshold tuning
Set the `/clusters` confidence threshold so low-frequency noise (the `dob_mismatch`
count=6 / low) is filtered by default (FR-16, Risk R-3). **Acceptance:** default
view hides low-confidence clusters; they appear when explicitly requested.

---

# PHASE 5 — Demo + submission (Day 7–8)

- **Golden path:** Rahima Begum — English Aadhaar + Bengali ration → `name_mismatch`
  → "you are one of many" zoom-out to the Silchar cluster.
- **Record a screen-capture backup** of the whole flow (Risk R-4 insurance).
- **README:** setup, free-tier stack disclosure, build-assist tooling
  (Claude Code / DeepSeek Flash V4 / Stitch), and the explicit "what Mou does
  NOT do" boundary (no eligibility verdicts, no record edits).
- **Deck:** lead with the inversion — one rejection is misfortune; many sharing
  one root cause at one shop is an accountability report.

---

## Two-person division (parallel from Day 1)

| Builder track | Owns |
|---|---|
| **Backend / AI** | OCR spike, matching, rules, explain+fallback, events, clustering, seed |
| **Frontend** | Flutter app flow, Next.js dashboard — both unblocked by the mock from Day 1 |

## Critical path (the things that sink the demo if late)
1. OCR works on real photos (Task 1.1, Risk R-1)
2. Begum/Begam matching lands correctly (Task 2.1)
3. Fallback explanation works offline (Task 2.3, Risk R-4)
Everything else has slack. Protect these three.
