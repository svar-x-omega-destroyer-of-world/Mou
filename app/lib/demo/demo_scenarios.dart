/// Hackathon Demo Mode — deterministic, presentation-safe scenarios.
///
/// These power the "Try Demo" path only.  The complete user flow is preserved
/// (language → upload Aadhaar → upload ration → verify → results); the only
/// thing demo mode changes is *where the diagnosis comes from*: instead of
/// relying on live OCR / matching / Gemini (which can produce blurry-photo
/// errors or variable output on stage), we inject a fixed, polished result for
/// the chosen scenario.  Live Verification is completely untouched.
///
/// IMPORTANT: nothing here calls the backend.  A [DemoScenario] is turned into
/// a regular [Diagnosis] via [toDiagnosis] so the existing result screens render
/// it exactly as if the server had returned it (explanation_source = 'gemini').
library;

import 'package:flutter/material.dart';

import '../api/mou_api.dart';

/// Polished status shown on the verification + result screens.
enum DemoStatus { approved, reviewRequired, highRisk }

/// Risk band shown alongside the AI assessment.
enum DemoRisk { low, medium, high }

/// One self-contained, deterministic demo case.
class DemoScenario {
  final String id;

  // ── Picker presentation ────────────────────────────────────────────────────
  final IconData icon;

  // ── Extracted document fields (what the verify screen shows) ───────────────
  final String aadhaarName;
  final String aadhaarDob;
  final String rationName; // romanised, as printed
  final String rationDob;

  // ── Comparison outcome (deterministic) ─────────────────────────────────────
  final bool nameMatch;
  final bool dobMatch;

  // ── Headline result ────────────────────────────────────────────────────────
  final DemoStatus status;
  final int confidencePercent; // e.g. 99
  final DemoRisk risk;

  // ── Diagnosis mapping (drives the existing result widgets) ─────────────────
  final RootCause rootCause;
  final Confidence confidence;

  // ── Gemini-quality, pre-written AI copy ────────────────────────────────────
  final String aiAnalysis;
  final String aiRecommendation;
  final NextStep nextStep;

  const DemoScenario({
    required this.id,
    required this.icon,
    required this.aadhaarName,
    required this.aadhaarDob,
    required this.rationName,
    required this.rationDob,
    required this.nameMatch,
    required this.dobMatch,
    required this.status,
    required this.confidencePercent,
    required this.risk,
    required this.rootCause,
    required this.confidence,
    required this.aiAnalysis,
    required this.aiRecommendation,
    required this.nextStep,
  });

  static const String _disclaimer =
      'This is guidance based on your document photos, not an official '
      'eligibility decision. Mou only reads your own documents and never '
      'accesses or changes any government record.';

  /// Build a regular [Diagnosis] so the unchanged result screens can render it.
  Diagnosis toDiagnosis() => Diagnosis(
        rootCause: rootCause,
        confidence: confidence,
        extracted: Extracted(
          aadhaarName: aadhaarName,
          rationNameScript: '',
          rationNameRomanized: rationName,
          aadhaarDob: aadhaarDob,
          rationDob: rationDob,
        ),
        explanation: aiAnalysis,
        nextStep: nextStep,
        disclaimer: _disclaimer,
        explanationSource: 'gemini',
        // Empty caseId disables the live /feedback POST (no real event exists).
        caseId: '',
      );
}

/// The four scenarios, in picker order.
const List<DemoScenario> kDemoScenarios = [
  // 1 ── Perfect Match ────────────────────────────────────────────────────────
  DemoScenario(
    id: 'perfect_match',
    icon: Icons.verified_outlined,
    aadhaarName: 'Dino Saren',
    aadhaarDob: '13-04-2008',
    rationName: 'DINO SAREN',
    rationDob: '13-04-2008',
    nameMatch: true,
    dobMatch: true,
    status: DemoStatus.approved,
    confidencePercent: 99,
    risk: DemoRisk.low,
    rootCause: RootCause.noIssues,
    confidence: Confidence.high,
    aiAnalysis:
        'Both your Aadhaar and ration card show the same name (Dino Saren) '
        'and the same date of birth (13-04-2008). The two records are '
        'consistent, so there is no document mismatch that would silently '
        'block your PDS / ONORC ration benefits.',
    aiRecommendation:
        'No correction to your documents is needed. If you are still turned '
        'away at the Fair Price Shop, the cause is most likely operational '
        '(e-POS device, stock, or the biometric reader) rather than your '
        'records — ask the dealer to retry the transaction or visit again.',
    nextStep: NextStep(
      office: 'Your local Fair Price Shop',
      form: 'Ask the dealer to retry the e-POS transaction',
    ),
  ),

  // 2 ── Name Mismatch ──────────────────────────────────────────────────────
  DemoScenario(
    id: 'name_mismatch',
    icon: Icons.person_search_outlined,
    aadhaarName: 'Dino Saren',
    aadhaarDob: '13-04-2008',
    rationName: 'Deno Saren',
    rationDob: '13-04-2008',
    nameMatch: false,
    dobMatch: true,
    status: DemoStatus.reviewRequired,
    confidencePercent: 95,
    risk: DemoRisk.medium,
    rootCause: RootCause.nameMismatch,
    confidence: Confidence.high,
    aiAnalysis:
        'Your Aadhaar reads "Dino Saren" while your ration card reads '
        '"Deno Saren". The dates of birth match, so this is a spelling / '
        'transliteration difference in the name field — one of the most '
        'common causes of silent exclusion under ONORC, because the e-POS '
        'name check fails even though you are the same person.',
    aiRecommendation:
        'Get the name on one card corrected so both match exactly. The '
        'fastest route is usually to update the ration card name at your '
        'local PDS / Food & Civil Supplies office. Carry both cards as proof.',
    nextStep: NextStep(
      office: 'Local PDS / Food & Civil Supplies Office',
      form: 'Ration Card Correction / Modification Form',
    ),
  ),

  // 3 ── DOB Mismatch ───────────────────────────────────────────────────────
  DemoScenario(
    id: 'dob_mismatch',
    icon: Icons.cake_outlined,
    aadhaarName: 'Dino Saren',
    aadhaarDob: '13-04-2008',
    rationName: 'DINO SAREN',
    rationDob: '14-04-2008',
    nameMatch: true,
    dobMatch: false,
    status: DemoStatus.reviewRequired,
    confidencePercent: 97,
    risk: DemoRisk.medium,
    rootCause: RootCause.dobMismatch,
    confidence: Confidence.high,
    aiAnalysis:
        'The names match, but your Aadhaar date of birth (13-04-2008) differs '
        'from your ration card (14-04-2008) by one day. Even a single-digit '
        'difference can cause the age / eligibility check at the shop to fail.',
    aiRecommendation:
        'Apply to correct the date of birth on whichever card is wrong so '
        'both records agree. Bring documentary proof of your date of birth '
        'along with both cards.',
    nextStep: NextStep(
      office: 'Local PDS / Food & Civil Supplies Office',
      form: 'Ration Card Correction / Modification Form',
    ),
  ),

  // 4 ── Multiple Issues ────────────────────────────────────────────────────
  DemoScenario(
    id: 'multiple_issues',
    icon: Icons.warning_amber_outlined,
    aadhaarName: 'Dino Saren',
    aadhaarDob: '13-04-2008',
    rationName: 'Deno Soren',
    rationDob: '14-04-2008',
    nameMatch: false,
    dobMatch: false,
    status: DemoStatus.highRisk,
    confidencePercent: 98,
    risk: DemoRisk.high,
    rootCause: RootCause.nameMismatch,
    confidence: Confidence.high,
    aiAnalysis:
        'Two fields disagree between your documents. The name differs '
        '("Dino Saren" on Aadhaar vs "Deno Soren" on the ration card) and the '
        'date of birth differs (13-04-2008 vs 14-04-2008). Multiple '
        'mismatches sharply increase the chance of an automated rejection at '
        'the Fair Price Shop.',
    aiRecommendation:
        'Both the name and the date of birth need to be reconciled so the two '
        'cards match. Visit your PDS / Food & Civil Supplies office to update '
        'the ration card, carrying your Aadhaar and proof of date of birth.',
    nextStep: NextStep(
      office: 'Local PDS / Food & Civil Supplies Office',
      form: 'Ration Card Correction / Modification Form',
    ),
  ),
];
