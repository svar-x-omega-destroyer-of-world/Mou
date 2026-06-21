import 'package:flutter/material.dart';
import '../api/mou_api.dart';
import '../l10n/strings.dart';
import '../theme.dart';

/// Step 4 — full diagnosis result screen (SRS §10.1).
///
/// Renders:
///   • Root cause label + confidence badge
///   • Plain-language explanation (Gemini or fallback)
///   • Next step: office + form  (FR-9)
///   • Disclaimer (FR-20)
///   • Explanation source indicator (gemini / offline-fallback)
///   • "You are one of many" cluster banner (FR-12)
///   • Flag as incorrect (FR-19)
class Step4Results extends StatefulWidget {
  final Diagnosis? diagnosis;
  final String? diagnosisError;
  final String? fpsLocation;
  final VoidCallback onStartOver;

  const Step4Results({
    super.key,
    this.diagnosis,
    this.diagnosisError,
    this.fpsLocation,
    required this.onStartOver,
  });

  @override
  State<Step4Results> createState() => _Step4ResultsState();
}

class _Step4ResultsState extends State<Step4Results> {
  List<Cluster>? _clusters;
  bool _feedbackSent = false;
  bool _loadingFeedback = false;
  bool _showFeedbackForm = false;
  final _feedbackController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadClusters();
  }

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  Future<void> _loadClusters() async {
    try {
      final data = await MouApi.instance.clusters();
      if (mounted) setState(() => _clusters = data);
    } catch (_) {
      // Cluster banner is optional — never block the result
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppText.of(context);
    if (widget.diagnosisError != null && widget.diagnosis == null) {
      return _ErrorResultView(
        error: widget.diagnosisError!,
        onStartOver: widget.onStartOver,
      );
    }

    final d = widget.diagnosis;
    if (d == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Root cause hero ───────────────────────────────────────────
          _RootCauseHero(diagnosis: d),
          const SizedBox(height: 24),

          // ── Explanation ───────────────────────────────────────────────
          _SectionCard(
            icon: Icons.lightbulb_outline,
            title: t.likelyCause,
            child: Text(
              d.explanation,
              style: const TextStyle(
                  fontSize: 16, height: 1.55, color: AppColors.onSurface),
            ),
          ),
          const SizedBox(height: 16),

          // ── Next step (FR-9) ──────────────────────────────────────────
          _SectionCard(
            icon: Icons.directions_walk,
            title: t.whatToDoNext,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _StepRow(
                    icon: Icons.location_city,
                    label: t.goTo,
                    value: d.nextStep.office),
                const SizedBox(height: 10),
                _StepRow(
                    icon: Icons.description_outlined,
                    label: t.askForForm,
                    value: d.nextStep.form),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF7F1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline,
                          size: 18, color: AppColors.secondary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          t.bringBoth,
                          style: const TextStyle(
                              fontSize: 13, color: AppColors.secondary),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Cluster banner (FR-12) ────────────────────────────────────
          if (_clusters != null) _ClusterBanner(
            clusters: _clusters!,
            fpsLocation: widget.fpsLocation,
            rootCause: d.rootCause,
          ),

          if (_clusters != null) const SizedBox(height: 16),

          // ── Disclaimer (FR-20) ────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.outlineVariant, width: 1.5),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.gavel_outlined,
                    color: AppColors.primary, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    d.disclaimer,
                    style: const TextStyle(
                        fontSize: 14, color: AppColors.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // ── Explanation source ────────────────────────────────────────
          Center(
            child: _SourceBadge(source: d.explanationSource),
          ),

          const SizedBox(height: 32),

          // ── Flag as incorrect (FR-19) ─────────────────────────────────
          if (!_feedbackSent) ...[
            if (_showFeedbackForm) ...[
              _FeedbackForm(
                controller: _feedbackController,
                isLoading: _loadingFeedback,
                onSubmit: () => _submitFeedback(d),
                onCancel: () => setState(() => _showFeedbackForm = false),
              ),
            ] else ...[
              OutlinedButton.icon(
                onPressed: () =>
                    setState(() => _showFeedbackForm = true),
                icon: const Icon(Icons.flag_outlined),
                label: Text(t.flagIncorrect),
              ),
            ],
          ] else ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFEEF7F1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle,
                      color: AppColors.secondary, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      t.feedbackThanks,
                      style: const TextStyle(
                          fontSize: 14, color: AppColors.secondary),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 24),

          // ── Start over ────────────────────────────────────────────────
          OutlinedButton.icon(
            onPressed: widget.onStartOver,
            icon: const Icon(Icons.restart_alt),
            label: Text(t.startNewDiagnosis),
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Future<void> _submitFeedback(Diagnosis d) async {
    if (d.caseId.isEmpty) {
      if (mounted) {
        setState(() => _loadingFeedback = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppText.of(context).feedbackUnavailable),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }
    setState(() => _loadingFeedback = true);
    try {
      await MouApi.instance.submitFeedback(
        caseId: d.caseId,
        rootCause: d.rootCause,
        comment: _feedbackController.text.trim().isNotEmpty
            ? _feedbackController.text.trim()
            : null,
      );
      if (mounted) {
        setState(() {
          _feedbackSent = true;
          _loadingFeedback = false;
          _showFeedbackForm = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loadingFeedback = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppText.of(context).feedbackError),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }
}

// ── Root cause hero ───────────────────────────────────────────────────────────

class _RootCauseHero extends StatelessWidget {
  final Diagnosis diagnosis;

  const _RootCauseHero({required this.diagnosis});

  static const _colors = {
    RootCause.nameMismatch: Color(0xFFD4EDDA),
    RootCause.dobMismatch: Color(0xFFFFF3CD),
    RootCause.seedingGap: Color(0xFFD1ECF1),
    RootCause.ekycIncomplete: Color(0xFFFFF3CD),
    RootCause.biometricFailure: Color(0xFFF8D7DA),
    RootCause.unknown: Color(0xFFE2E3E5),
  };

  static const _fgColors = {
    RootCause.nameMismatch: Color(0xFF155724),
    RootCause.dobMismatch: Color(0xFF856404),
    RootCause.seedingGap: Color(0xFF0C5460),
    RootCause.ekycIncomplete: Color(0xFF856404),
    RootCause.biometricFailure: Color(0xFF721C24),
    RootCause.unknown: Color(0xFF383D41),
  };

  static const _icons = {
    RootCause.nameMismatch: Icons.person_search,
    RootCause.dobMismatch: Icons.cake_outlined,
    RootCause.seedingGap: Icons.link_off,
    RootCause.ekycIncomplete: Icons.verified_user_outlined,
    RootCause.biometricFailure: Icons.fingerprint,
    RootCause.unknown: Icons.help_outline,
  };

  @override
  Widget build(BuildContext context) {
    final t = AppText.of(context);
    final bg = _colors[diagnosis.rootCause] ?? const Color(0xFFE2E3E5);
    final fg = _fgColors[diagnosis.rootCause] ?? const Color(0xFF383D41);
    final icon = _icons[diagnosis.rootCause] ?? Icons.help_outline;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: fg.withValues(alpha: 0.3), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: fg, size: 32),
              const SizedBox(width: 12),
              Expanded(
                child: Text(t.weFoundIssue,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.onSurfaceVariant,
                        letterSpacing: 0.5)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            t.rootCauseLabel(diagnosis.rootCause),
            style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: fg,
                letterSpacing: -0.5),
          ),
          const SizedBox(height: 10),
          _ConfidenceRow(confidence: diagnosis.confidence),
        ],
      ),
    );
  }
}

class _ConfidenceRow extends StatelessWidget {
  final Confidence confidence;
  const _ConfidenceRow({required this.confidence});

  @override
  Widget build(BuildContext context) {
    Color c;
    switch (confidence) {
      case Confidence.high:
        c = const Color(0xFF155724);
        break;
      case Confidence.medium:
        c = const Color(0xFF856404);
        break;
      case Confidence.low:
        c = const Color(0xFF721C24);
        break;
    }
    final label = AppText.of(context).confidenceRow(confidence);
    return Row(
      children: [
        Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label,
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600, color: c)),
      ],
    );
  }
}

// ── Section card ──────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;

  const _SectionCard(
      {required this.icon, required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.7), width: 1.5),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: AppColors.secondary),
              const SizedBox(width: 8),
              Text(title,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                      letterSpacing: 0.3)),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

// ── Step row ──────────────────────────────────────────────────────────────────

class _StepRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StepRow(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: AppColors.primary),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label.toUpperCase(),
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.onSurfaceVariant,
                    letterSpacing: 1)),
            const SizedBox(height: 3),
            Text(value,
                style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary)),
          ],
        ),
      ],
    );
  }
}

// ── Cluster banner ────────────────────────────────────────────────────────────

class _ClusterBanner extends StatelessWidget {
  final List<Cluster> clusters;
  final String? fpsLocation;
  final RootCause rootCause;

  const _ClusterBanner({
    required this.clusters,
    required this.fpsLocation,
    required this.rootCause,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppText.of(context);
    // Find the matching cluster for this user's location + root cause
    Cluster? match;
    if (fpsLocation != null && fpsLocation!.isNotEmpty) {
      match = clusters.where((c) =>
          c.rootCause == rootCause &&
          c.fpsLocation.toLowerCase().contains(fpsLocation!.toLowerCase())).firstOrNull;
    }
    match ??= clusters.where((c) => c.rootCause == rootCause).firstOrNull;

    final int totalAffected = clusters.fold(
        0, (sum, c) => sum + c.beneficiariesAffected);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.05),
            AppColors.secondary.withValues(alpha: 0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.secondary.withValues(alpha: 0.4), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.people_outline,
                  color: AppColors.secondary, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(t.youAreNotAlone,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (match != null) ...[
            Text(
              t.clusterMatch(match.beneficiariesAffected, match.fpsLocation,
                  t.rootCauseLabel(match.rootCause)),
              style: const TextStyle(
                  fontSize: 15, height: 1.5, color: AppColors.onSurface),
            ),
          ] else ...[
            Text(
              t.clusterGeneral(totalAffected, clusters.length),
              style: const TextStyle(
                  fontSize: 15, height: 1.5, color: AppColors.onSurface),
            ),
          ],
          const SizedBox(height: 10),
          Text(
            t.everyDiagnosis,
            style: const TextStyle(
                fontSize: 13,
                color: AppColors.onSurfaceVariant,
                fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }
}

// ── Source badge ──────────────────────────────────────────────────────────────

class _SourceBadge extends StatelessWidget {
  final String source;
  const _SourceBadge({required this.source});

  @override
  Widget build(BuildContext context) {
    final isGemini = source == 'gemini';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: isGemini
            ? const Color(0xFFE8F0FE)
            : AppColors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isGemini ? Icons.auto_awesome : Icons.offline_bolt,
            size: 14,
            color: isGemini
                ? const Color(0xFF1A73E8)
                : AppColors.onSurfaceVariant,
          ),
          const SizedBox(width: 5),
          Text(
            isGemini
                ? AppText.of(context).aiGenerated
                : AppText.of(context).offlineExplanation,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isGemini
                    ? const Color(0xFF1A73E8)
                    : AppColors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

// ── Feedback form (FR-19) ─────────────────────────────────────────────────────

class _FeedbackForm extends StatelessWidget {
  final TextEditingController controller;
  final bool isLoading;
  final VoidCallback onSubmit;
  final VoidCallback onCancel;

  const _FeedbackForm({
    required this.controller,
    required this.isLoading,
    required this.onSubmit,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppText.of(context);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.outlineVariant, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t.flagAsIncorrect,
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary)),
          const SizedBox(height: 8),
          Text(
            t.feedbackPrompt,
            style: const TextStyle(
                fontSize: 13, color: AppColors.onSurfaceVariant),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: controller,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: t.feedbackHint,
              filled: true,
              fillColor: AppColors.surfaceContainerLow,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide:
                    const BorderSide(color: AppColors.outlineVariant),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide:
                    const BorderSide(color: AppColors.primary, width: 2),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: isLoading ? null : onCancel,
                  child: Text(t.cancel),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: isLoading ? null : onSubmit,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary),
                  child: isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 3))
                      : Text(t.submit),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Error fallback (no diagnosis at all) ─────────────────────────────────────

class _ErrorResultView extends StatelessWidget {
  final String error;
  final VoidCallback onStartOver;

  const _ErrorResultView({required this.error, required this.onStartOver});

  @override
  Widget build(BuildContext context) {
    final t = AppText.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.errorContainer,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.error_outline,
                  color: AppColors.error, size: 44),
            ),
            const SizedBox(height: 28),
            Text(t.diagnosisFailed,
                style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary)),
            const SizedBox(height: 14),
            Text(error,
                style: const TextStyle(
                    fontSize: 15, color: AppColors.onSurfaceVariant),
                textAlign: TextAlign.center),
            const SizedBox(height: 36),
            ElevatedButton.icon(
              onPressed: onStartOver,
              icon: const Icon(Icons.restart_alt),
              label: Text(t.startOver),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary),
            ),
          ],
        ),
      ),
    );
  }
}
