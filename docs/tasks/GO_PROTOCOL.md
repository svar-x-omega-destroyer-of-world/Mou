# GO protocol

**You (the human) type `go`. Work proceeds. No questions unless a hard invariant is at stake.**

This is the contract between you, me (planner), and DeepSeek (executor) so a single
word moves the build forward without friction.

---

## What `go` means

- **To me (planner):** emit the next unstarted task's executor card (full code +
  commands + acceptance), ready to paste to DeepSeek. I do **not** ask you to
  choose, confirm, or clarify. I pick the documented default and note it in one line.
- **To DeepSeek (executor):** take the current card, do it end-to-end, run its
  acceptance test, fill in any `# VERDICT` / status line, then stop and report
  **one line**: `Task X.Y — PASS` or `Task X.Y — BLOCKED: <reason>`.

`go again` / `next` = advance to the following task. `go X.Y` = jump to a specific card.

---

## Task queue (order = build_plan.md)

| # | Task | Card | Status |
|---|------|------|--------|
| 1.0 | Place Mou's own Vision API key (HUMAN) | `task_1_0_vision_credentials.md` | ✅ done — fresh key in place (the 403 was billing, now resolved) |
| 1.1 | OCR spike | `task_1_1_ocr_spike.md` | ✅ **DONE** — Risk R-1 cleared; VERDICT filled (Vision primary, Tesseract fallback) |
| 1.2 | Confirm contract + run mock backend | _emit on go_ | ◀ **NEXT** |
| 1.3 | Dashboard skeleton + deploy | _emit on go_ | queued |
| 1.4 | App connects to mock | _emit on go_ | queued |
| 2.1–2.5 | Diagnosis engine + citizen app | _emit on go_ | queued |
| 3.1–3.4 | Event store + dashboard | _emit on go_ | queued |
| 4.x / 5.x | Resilience + demo | _emit on go_ | queued |

---

## Decision policy — defaults I apply so nobody asks you

1. **Contract / rules / thresholds:** never reinterpret. Use them verbatim from
   `contract/openapi.yaml` and `rules_spec.md`. No question needed.
2. **Library / version choices:** pick the one already proven in the repo or pinned
   in a card. Default to free-tier stack in CLAUDE.md §Tech stack.
3. **File layout / naming:** match existing patterns. Don't invent new structure.
4. **Missing optional input:** proceed with a sensible stub and note it; do not block.
5. **Anything cosmetic** (copy, table layout, log format): executor's discretion.

## When work DOES stop and ask (the only times)

- A step would break one of the **6 invariants** in `CLAUDE.md` §Invariants
  (LLM deciding, asserting eligibility, writing gov records, offline-break,
  storing names/Aadhaar, changing the contract).
- A card's rule/threshold is genuinely ambiguous against `rules_spec.md`.
- A required **human-only input** is missing (e.g. the ration-card photos for 1.1,
  a deploy token). Then: one-line ask, naming exactly what's needed.

Anything else: pick the default, proceed, note it in one line.

---

## Right now

Phase 1 de-risking is done: Tasks 1.0 and 1.1 are complete. The OCR spike ran
against real photos — Risk **R-1 is cleared**, names extract cleanly in Bengali +
English, and the `# VERDICT:` line in `ocr_spike.py` is filled (Google Vision as
primary OCR, Tesseract `ben+eng` as fallback).

**Next: Task 1.2 — confirm contract + run mock backend.** Say `go` to emit its card.
