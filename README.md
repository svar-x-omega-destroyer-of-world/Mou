# Mou — Make Exclusion Visible

A hackathon project that answers one question: *why did my ration stop?*

Mou reads your Aadhaar and ration card, figures out which backend defect is
blocking your rations, and — if enough people at the same shop have the same
problem — surfaces it as a pattern officials can actually act on.

**One rejection is a personal misfortune. Many rejections sharing one root cause
at one shop is an accountability report — and Mou is what makes it visible.**

Built June 14–21 2026.

---

## How it works

```
Flutter app ─┐              ┌─ SQLite (anonymised events only)
             ├► FastAPI ────┤
Dashboard  ──┘              └─ clusters computed once, both clients identical
```

Two frontends, one backend, one API contract (`contract/openapi.yaml`) that never changes.

---

## Quick start

### Backend

```bash
cd backend
python3 -m venv .venv
./.venv/bin/pip install -r requirements.txt
./.venv/bin/uvicorn app.main:app --reload      # → http://localhost:8000
```

Seed synthetic data so the dashboard has volume:

```bash
./.venv/bin/python seed.py
```

### Dashboard

```bash
cd dashboard
npm install
npm run dev                                    # → http://localhost:3000
```

### Flutter app

```bash
cd app
flutter pub get
flutter run
```

> **Physical device?** Edit `app/lib/api/mou_api.dart` line 30 and change
> `_kDefaultBaseUrl` to your machine's LAN IP (e.g. `http://192.168.1.42:8000`).
> Android emulator: use `http://10.0.2.2:8000`.

---

## The Rahima Begum golden path

1. Upload an English Aadhaar ("Rahima Begum") + a Bengali ration card ("রহিমা বেগম")
2. Select symptom: "Turned away at shop" → FPS: "Silchar FPS #4471"
3. Mou diagnoses `name_mismatch` — same person, different transliteration across scripts
4. Next step: Circle Office → RC Correction form
5. Dashboard shows **40 people** with the same issue at the same shop

---

## Stack

| Piece | Technology |
|-------|-----------|
| OCR | Google Cloud Vision (REST), falls back to Tesseract `ben+eng` |
| Name matching | indic-transliteration + rapidfuzz (transliteration-aware) |
| Root-cause rules | 6 deterministic Python checks — no LLM on the decision path |
| Explanations | Gemini 1.5 Flash when available, pre-written local fallbacks when not |
| Storage | SQLite — anonymised events only (`root_cause`, `fps_location`, `document_pattern`) |
| Backend | FastAPI (Python 3.13) |
| Citizen app | Flutter (Dart) |
| Officials dashboard | Next.js 16 + Tailwind CSS |
| Build assist | Claude Code, Sonnet 4.6 |

---

## What Mou will not do

- Decide whether you qualify for rations. It says "likely cause" and leaves it there.
- Edit any government database. It reads documents, full stop.
- Let an AI decide the root cause. That is pure deterministic Python rules.
- Store your name or Aadhaar number. Events are anonymised by design.
- Deviate from the locked API contract. Both frontends depend on it.

---

## Environment variables

| Variable | Where | Purpose |
|----------|-------|---------|
| `GOOGLE_VISION_API_KEY` | `backend/.env` | Cloud Vision OCR (falls back to Tesseract if absent) |
| `GEMINI_API_KEY` | `backend/.env` | Explanation generation (falls back to local strings if absent) |
| `BACKEND_URL` | `dashboard/.env.local` | Override backend URL for dashboard (default: `http://localhost:8000`) |

---

## Live

- **Dashboard:** https://moudashboard.vercel.app

---

*Built with Claude Code and probably too much chai.*
