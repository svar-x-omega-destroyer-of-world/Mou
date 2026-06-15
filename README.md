# Mou — Make Exclusion Visible

**Hackathon build, June 14–21 2026.** Mou tells a PDS/ONORC beneficiary *why*
they were silently cut off from their rations, and aggregates those cases so
officials see systemic defects instead of isolated complaints.

## Architecture

```
Flutter citizen app ─┐                    ┌─ SQLite event store
                     ├─► FastAPI backend ─┤   (anonymised)
Next.js dashboard  ──┘    (single         └─ computes clusters
  (officials,            source of              once
   read-only)            truth)
```

Two frontends, one backend, one locked JSON contract (`contract/openapi.yaml`).

## Repos

| Repo | Tech | URL |
|------|------|-----|
| Backend + Flutter app | FastAPI + Flutter | `github.com/svar-x-omega-destroyer-of-world/Mou` |
| Dashboard | Next.js 16 + Tailwind | `github.com/svar-x-omega-destroyer-of-world/Mou-Dashboard` |

## Quick start

```bash
# Backend (port 8000)
cd backend
python3 -m venv .venv
./.venv/bin/pip install -r requirements.txt
./.venv/bin/uvicorn app.main:app --reload

# Seed demo data
./.venv/bin/python seed.py

# Dashboard (port 3000)
cd mou_dashboard    # separate repo
npm install
npm run dev
```

## Golden path — "Rahima Begum"

1. Upload an English Aadhaar ("Rahima Begum") + Bengali ration card ("রহিমা বেগম")
2. System returns `name_mismatch` — the flagship transliteration defect
3. The dashboard shows **40 beneficiaries** with the same pattern at Silchar FPS
4. One rejection is misfortune; 40 sharing one root cause at one shop is a report

## Tech stack (all free-tier)

- **OCR:** Google Cloud Vision REST (primary) → Tesseract `ben+eng` (fallback)
- **Matching:** `indic-transliteration` (ITRANS) + `rapidfuzz` token_sort_ratio
- **Rules:** 6 deterministic rules, no LLM on classification path (FR-18)
- **Explanation:** Gemini (personalised) → 6 pre-written local fallback strings
- **Store:** SQLite (anonymised events only — no names, no Aadhaar numbers)
- **Deploy:** Backend on Render/Railway, dashboard on Vercel, app as APK

## What Mou does NOT do

- **No eligibility decisions.** Output is always "likely cause" — never "you
  qualify" or "you don't qualify". (FR-10)
- **No government record modification.** Mou only reads the user's own
  documents. It never writes to any database it doesn't own. (FR-17)
- **No LLM on the decision path.** The root cause is chosen by deterministic
  Python rules. The LLM (Gemini) only rephrases the explanation text. (FR-18)
- **No personal data stored.** Events are anonymised to `{root_cause,
  fps_location, document_pattern}`. No names, no Aadhaar numbers. (SRS §7)
- **No contract changes.** The API shape (`openapi.yaml`) is locked — both
  frontends depend on it.

## Production URLs

- **Dashboard:** https://moudashboard.vercel.app
- **API:** Backend URL (set as `NEXT_PUBLIC_API_URL` for dashboard)

## Invariants (re-read before every backend change)

See `CLAUDE.md` §Invariants in the repo root.

---

*Built with Claude Code, DeepSeek Flash V4, and a lot of chai.*
