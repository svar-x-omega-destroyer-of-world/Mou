# Mou — Hackathon Status

**Hackathon window:** June 14–21, 2026  
**Today:** June 18 — Day 5 of 8, **3 days remaining**

---

## Phase completion

| Phase | Status | Notes |
|---|---|---|
| Phase 1 — De-risk + lock | ✅ Done | OCR spike, contract, mock backend, dashboard skeleton |
| Phase 2 — Diagnosis engine + citizen app | ✅ Done | Matching, rules, explain/fallback, full Flutter flow |
| Phase 3 — Event store + dashboard | ✅ Done | SQLite events, clustering, 101 seeded cases, dashboard live |
| Phase 4 — Resilience + Responsible-AI | ✅ Done | Fallback fires when Gemini down, graceful errors, threshold filter |
| Phase 5 — Demo + submission | 🔄 In progress | Recording, README polish, deck |

---

## Live deployments

| Service | URL | Status |
|---|---|---|
| Backend (Railway) | https://mou-backend-production.up.railway.app | Live |
| Dashboard (Vercel) | https://dashboard-rho-six-25.vercel.app | Live |
| Flutter APK | — | Build needed for physical device |

---

## Latest changes (June 18)

**OCR extraction rewrite** — fixed 5 bugs causing false name mismatches and
empty/garbage DOB values on real government cards (commit `e722e03`):

- `[A-Z\s.]` → `[A-Z .]` in Aadhaar name patterns — `\s` was crossing newlines
  and pulling DOB/address lines into the name field ("Andhaan", "Datinn" artefacts)
- `.+` → `[A-Za-zঀ-৿ .']{2,60}` in ration name capture — stops OCR-flattened
  documents from being consumed in one shot
- DOB now parses `DD Mon YYYY` format ("01 Jan 1990"); garbage strings return `None`
- Added `Name/নাম` pattern for Assamese ration cards with bare `Name:` labels
- Latin guard in `name_score()` — Latin ration names (e.g. "Dino Saren") now
  bypass `romanise()` instead of being mangled through Bengali ITRANS

**Verified:** "Dino Saren" vs "Dino Saren" → score 100 (was: false mismatch).
"Rahima Begum" vs "রহিমা বেগম" → score 83 (transliteration variance band, correct).

---

## Remaining before submission

- [ ] `flutter build apk --release` → APK for friend's Android device
- [ ] Screen-capture golden-path demo (Rahima Begum → cluster zoom-out)
- [ ] README: setup, free-tier stack, responsible-AI boundary statement
- [ ] Pitch deck: lead with the inversion (one rejection vs. cluster = accountability)

---

## Critical path — all green

1. ✅ OCR works on real photos (just fixed false-mismatch on Adivasi names)
2. ✅ Begum/Begam matching lands in 70–84 band
3. ✅ Fallback explanation works with no network / no Gemini key
