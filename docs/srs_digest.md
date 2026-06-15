# SRS Digest — Mou (the short version for the builder)

> This is the fast reference. The **full, authoritative** spec is
> `docs/Mou_SRS_v2.md` (and `Mou_SRS_v2.pdf`). If this digest and the full SRS
> ever disagree, the **full SRS wins** — go read it. Use this to know *which*
> requirement you're satisfying and to trace it by ID (FR-#).

---

## What Mou is (one paragraph)

A legitimate PDS/ONORC beneficiary is silently denied rations because of a
backend defect (name/DOB mismatch across Aadhaar vs ration card, Aadhaar not
seeded, e-KYC gap, or biometric failure). No notice is ever sent — they find out
only when turned away at the shop. **Mou diagnoses the likely cause from the
user's own documents, explains it in plain language, gives one concrete next
step, and aggregates anonymised cases so officials see systemic defects.**

**Mou does NOT:** decide eligibility, edit any government record, give legal/medical
advice, or guarantee outcomes. It flags; humans decide.

---

## Functional requirements (trace your work to these IDs)

Priority: **M = must-have for demo**, S = should-have, C = could-have.

### Intake (citizen app)
| ID | M/S | Requirement |
|----|----|-------------|
| FR-1 | **M** | Upload images of an Aadhaar card and a ration card. |
| FR-2 | S | Select a language; choose self-serve vs assisted (proxy) mode. |
| FR-3 | **M** | Capture a short structured symptom (e.g. turned away at FPS) + FPS location. |
| FR-4 | S | Detect unreadable/low-quality images and prompt re-upload. |

### Diagnosis engine (backend)
| ID | M/S | Requirement |
|----|----|-------------|
| FR-5 | **M** | Extract identity fields (name, DOB, IDs) via OCR, incl. ≥1 Indic script. |
| FR-6 | **M** | Transliteration-aware cross-document matching of names + key fields. |
| FR-7 | **M** | Classify into **exactly one** primary root cause via deterministic hardcoded rules. |
| FR-8 | **M** | Response includes the extracted fields from **both** docs for side-by-side verification. |
| FR-9 | **M** | Return a plain-language explanation + a concrete next step (office + form). |
| FR-10 | **M** | Express every diagnosis as "likely"/"may" — **never** a definitive verdict. |
| FR-11 | **M** | Use a pre-generated fallback explanation when the live LLM is unavailable. |

### Clustering & accountability
| ID | M/S | Requirement |
|----|----|-------------|
| FR-12 | **M** | Record each diagnosis as an anonymised event `{root_cause, location, document_pattern}`. |
| FR-13 | **M** | Cluster events sharing root cause + location into one systemic defect. |
| FR-14 | **M** | Rank clusters by number of distinct beneficiaries affected. |
| FR-15 | **M** | Dashboard shows ranked clusters, each expandable to its anonymised cases. |
| FR-16 | S | Only surface a cluster above a configurable confidence threshold. |

### Responsible-AI controls
| ID | M/S | Requirement |
|----|----|-------------|
| FR-17 | **M** | Never write to / modify any external government record. |
| FR-18 | **M** | Never output a definitive eligibility verdict — reserved for a human official. |
| FR-19 | S | Let a user flag a diagnosis as incorrect; log the feedback. |
| FR-20 | **M** | Show a clear disclaimer: Mou flags issues, not legal advice or guaranteed outcomes. |

> The **M** rows are the demo. If you're choosing what to build next, build an
> unfinished **M** before any **S**.

---

## Non-functional targets

| Area | Target |
|------|--------|
| Performance | End-to-end diagnosis ≤ 10 s typical |
| Usability | Core flow ≤ 4 steps; plain language throughout |
| Accessibility | Self-serve, assisted/proxy, and a voice-or-large-text path |
| Reliability | Live demo survives a network failure on the explanation path (offline fallback) |
| Privacy | No real personal data persisted; stored events anonymised — by design |
| Transparency | Every diagnosis shows its evidence; every cluster shows its cases |
| Portability | App runs as APK; dashboard runs in a standard browser |

---

## Hard constraints (SRS §2.4)

- Built entirely within the **June 14–21 2026** window.
- Eligibility / root-cause logic = **deterministic hardcoded rules (5–7)**. **No LLM on the eligibility path** — eliminates hallucinated verdicts.
- LLM (Gemini) is confined to **phrasing explanations**, with pre-generated local fallbacks so a network failure can't break the demo.
- Use **synthetic** documents and **synthetic** exclusion events for testing/clustering. No real beneficiary PII is collected or stored.

---

## Demo scope (SRS §11 — build to exactly this, no more)

- **One scheme** (PDS/ONORC); **one cross-script pair** (Bengali ration card + English Aadhaar).
- **Stage 1 (diagnosis) fully live** on a real scanned/photographed pair.
- **Clustering + dashboard demonstrated on synthetic data**, narrated as "every real diagnosis feeds this at scale".
- **Opening:** one named case (Rahima Begum) → zoom out to her cluster.

**Out of scope this build:** live government DB integration or write-back;
multiple schemes / Indic scripts beyond the demo pair; user accounts /
production security hardening.

---

## The one-line "why it matters" (for the pitch)

One rejection is a personal misfortune. **Many rejections sharing one root cause
at one shop is an accountability report — and Mou is what makes it visible.**
