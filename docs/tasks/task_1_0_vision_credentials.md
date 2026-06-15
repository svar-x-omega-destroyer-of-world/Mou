# Task 1.0 — Place Mou's own Vision API key (HUMAN, before 1.1)

Mou needs its **own** Google Cloud Vision access (not any other project's key). You
already have a **fresh Vision API key**, so this task is just placing it where the
spike can find it. No service account or JSON key download is required.

## Steps
1. Confirm the **Cloud Vision API** is enabled on the Google Cloud project that
   issued your fresh API key (Console → APIs & Services → Library → "Cloud Vision
   API" → Enable, if it is not already).
2. Create the file `backend/spikes/.env` (it is gitignored via `.env` / `.env.*`)
   with a single line:
   ```
   GOOGLE_VISION_API_KEY=YOUR_FRESH_KEY_HERE
   ```
   (Alternatively, `export GOOGLE_VISION_API_KEY=...` in your shell instead of the
   file — the spike checks the environment first, then the `.env` file.)

Free tier: Vision gives ~1,000 units/month free — enough for the spike + demo.

## Acceptance
`backend/spikes/.env` contains `GOOGLE_VISION_API_KEY=...` (or the env var is
exported). The Task 1.1 spike run is the real check that the key works.

## Do NOT
- Do NOT commit the key or the `.env` file.
- Do NOT hardcode the key into any `.py` file — env var / `.env` only.
- Do NOT reuse any other project's key. In particular, the `~/Documents/ec` key is
  off-limits; Mou uses its **own** fresh key.
