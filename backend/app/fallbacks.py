"""Pre-written fallback explanation strings (FR-11, Risk R-4).

Every root cause has a local fallback string so the diagnosis endpoint never
500s when Gemini is unavailable.  The Gemini version (when available) uses the
extracted fields to personalise the message; these fallbacks are generic but
informative.

Each string:
  - Uses "likely cause" framing (FR-10) — never "you qualify / don't qualify".
  - Includes a concrete next step.
  - Works offline with zero dependencies.
"""
from __future__ import annotations

from app.schemas import RootCause

# Each entry is keyed by RootCause enum value.
# {name} / {location} etc. can be .format()'d by the caller if desired.
_FALLBACKS: dict[str, str] = {
    RootCause.name_mismatch: (
        "The name on your Aadhaar card and your ration card look slightly "
        "different when compared side by side.  Even a small spelling "
        "difference can prevent the shop from confirming your identity.  "
        "Likely cause: a clerical difference in how your name was entered "
        "across the two records.  As a next step, visit your local Circle "
        "Office with both documents and ask for a 'Name Correction' on your "
        "ration card record."
    ),
    RootCause.dob_mismatch: (
        "The date of birth on your Aadhaar card does not match the date of "
        "birth on your ration card.  Likely cause: the two records were "
        "created at different times and the details were entered separately.  "
        "As a next step, visit your local Circle Office with both documents "
        "and ask for the date of birth to be corrected on your ration card."
    ),
    RootCause.seeding_gap: (
        "Your Aadhaar number may not be linked (seeded) to your ration card "
        "record in the system.  Without this link, the shop cannot see your "
        "entitlement even though you have both documents.  Likely cause: the "
        "seeding was either never done or was not saved.  As a next step, "
        "visit your local Circle Office and request 'Aadhaar seeding' for "
        "your ration card."
    ),
    RootCause.ekyc_incomplete: (
        "Your e-KYC (electronic Know Your Customer) process appears to be "
        "incomplete on your ration card record.  Until it is finished, the "
        "system holds your entitlement.  Likely cause: the e-KYC was started "
        "but not completed.  As a next step, visit your local Circle Office "
        "with your Aadhaar card and complete the e-KYC process at the "
        "counter."
    ),
    RootCause.biometric_failure: (
        "Your fingerprint or iris scan did not match at the shop.  Likely "
        "cause: worn fingerprints (common for manual workers), a temporary "
        "skin condition, or a reader issue at the shop.  As a next step, "
        "try again after cleaning your hands, or ask the shop to try a "
        "different finger.  If the problem persists, visit your Circle "
        "Office to register an alternate authentication method."
    ),
    RootCause.unknown: (
        "We could not identify a single likely cause from the documents and "
        "information you provided.  This does not mean your ration is not "
        "being wrongly withheld — it means the pattern is not one of the "
        "common defects the system looks for.  As a next step, please visit "
        "your local Circle Office with both documents and ask them to check "
        "your ration card record manually."
    ),
}


def get_fallback(root_cause: str, **kwargs) -> str:
    """Return the pre-written fallback explanation for *root_cause*.

    Args:
        root_cause: One of the RootCause enum string values.
        **kwargs: Optional format arguments (currently unused but kept for
                  consistency with the Gemini path).

    Returns:
        A plain-language explanation that works offline.
    """
    msg = _FALLBACKS.get(root_cause)
    if msg is None:
        msg = _FALLBACKS[RootCause.unknown]
    if kwargs:
        try:
            msg = msg.format(**kwargs)
        except (KeyError, ValueError):
            pass  # fallback is fine as-is
    return msg
