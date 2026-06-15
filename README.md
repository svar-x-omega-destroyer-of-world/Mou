# Mou — Make Exclusion Visible

A hackathon project that answers one question: *why did my ration stop?*

Mou reads your Aadhaar and ration card, figures out which backend defect is
blocking your rations, and — if enough people at the same shop have the same
problem — surfaces it as a pattern officials can actually act on.

Built June 14–21 2026.

---

## How it works

```
Flutter app ─┐              ┌─ SQLite (anonymised events only)
             ├► FastAPI ────┤
Dashboard  ──┘              └─ clusters computed once
```

Two frontends, one backend, one API contract that never changes.

## Repos

- **Backend + app** — FastAPI + Flutter → `github.com/svar-x-omega-destroyer-of-world/Mou`
- **Dashboard** — Next.js → `github.com/svar-x-omega-destroyer-of-world/Mou-Dashboard`

## Quick start

```bash
# Backend
cd backend
python3 -m venv .venv
./.venv/bin/pip install -r requirements.txt
./.venv/bin/uvicorn app.main:app --reload

# Seed some data so the dashboard isn't empty
./.venv/bin/python seed.py

# Dashboard (separate repo)
cd mou_dashboard
npm install
npm run dev
```

## The Rahima Begum flow

1. Upload an English Aadhaar ("Rahima Begum") + a Bengali ration card ("রহিমা বেগম")
2. Mou says `name_mismatch` — just a spelling difference, but enough to break things
3. The dashboard shows **40 people** with the same mismatch at the same Silchar shop
4. One person being turned away is hard to investigate. Forty at one shop is a pattern.

## Stack

| Piece | What we used |
|-------|-------------|
| OCR | Google Cloud Vision, falls back to Tesseract |
| Name matching | indic-transliteration + rapidfuzz |
| Rules | 6 deterministic checks — no AI deciding anything |
| Explanations | Gemini when available, local fallbacks when not |
| Storage | SQLite, nothing but event metadata stored |
| Frontends | Flutter (app) + Next.js (dashboard) |

## What Mou will not do

- Say whether you qualify for rations. It says "likely cause" and leaves it there.
- Edit any government database. It reads documents, full stop.
- Let an AI decide the root cause. That's pure Python rules.
- Store your name or Aadhaar number. Events are anonymised.
- Change the API on you. The contract is locked.

## Live

- **Dashboard:** https://moudashboard.vercel.app

---

*Built with Claude Code, DeepSeek, and probably too much chai.*
