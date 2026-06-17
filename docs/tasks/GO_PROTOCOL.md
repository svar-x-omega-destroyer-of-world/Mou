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

## Lane — build Team Member 1's work only

This workspace builds **Team Member 1's** half: Backend & AI/OCR. **Team Member 2**
(Flutter app + Next.js dashboard) is a separate human teammate building in parallel
against the same locked contract. The executor does **not** build TM2's items.

**On every `go`, before emitting or executing a card:**
1. Open `docs/execution_phases.md` and read the **Team Member 1** column for the
   current phase — that column is the authoritative list of what is yours to build.
2. From the queue below (order = `build_plan.md`), take the next unstarted card in
   **TM1's lane**. Skip `TM2` rows. For `mixed` rows, build only the TM1-column items
   named in `execution_phases.md`.
3. Where your work touches a TM2 surface (e.g. the dashboard reading `/clusters`),
   build to the **locked contract / mock** — never to TM2's code.

---

## Task queue (order = build_plan.md)

| # | Task | Lane | Card | Status |
|---|------|------|------|--------|
| 1.0 | Place Mou's own Vision API key | TM1 (human) | `task_1_0_vision_credentials.md` | ✅ done — fresh key in place (the 403 was billing, now resolved) |
| 1.1 | OCR spike | TM1 | `task_1_1_ocr_spike.md` | ✅ **DONE** — Risk R-1 cleared; VERDICT filled (Vision primary, Tesseract fallback) |
| 1.2 | Confirm contract + run backend | TM1 | done | ✅ contract locked; real backend built (past mock) |
| 1.3 | Dashboard skeleton + deploy | TM2 | — | teammate's lane |
| 1.4 | App connects to mock | TM2 | — | teammate's lane |
| 2.1–2.5 | Diagnosis engine (matching, rules, explanation) | TM1 | done | ✅ built + tested |
| 3.1–3.4 | Event store + clustering + seed | TM1 | done | ✅ built + tested; store seeded (101 events) |
| 4.x / 5.x | Resilience + demo | mixed / collab | partial | ✅ TM1 backend (thresholds, fallbacks, feedback) done; demo + deck remain (collab) |

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

**Team Member 1's backend/AI lane is COMPLETE and verified.** The full pipeline is
built and committed (OCR → extract → match → rules → explain → events → clustering),
the event store is seeded (101 synthetic events), and the test suite is **46/46 green**.
R-1 is cleared. There is no remaining `go`-style build work in TM1's lane.

**The objective has shifted from build → win.** Remaining levers (none are TM1 solo
build tasks): (1) integrate TM2's Flutter app + dashboard against the live backend;
(2) the golden-path demo + deck (see `docs/positioning.md`); (3) optional hardening —
give the cluster tests their own seeded DB instead of depending on a pre-seeded
`mou_events.db`.
