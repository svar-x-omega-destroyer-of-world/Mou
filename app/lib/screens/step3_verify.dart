import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../api/mou_api.dart';
import '../l10n/strings.dart';
import '../theme.dart';

/// Step 3 — fires the real POST /diagnose, then shows extracted fields
/// side-by-side for user verification (FR-8).
class Step3Verify extends StatefulWidget {
  final XFile aadhaarImage;
  final XFile rationCardImage;
  final Symptom symptom;
  final String? fpsLocation;
  final String? language;
  final void Function(Diagnosis? diagnosis, String? error) onDiagnosisReady;
  final VoidCallback onNext;
  final VoidCallback onBack;

  const Step3Verify({
    super.key,
    required this.aadhaarImage,
    required this.rationCardImage,
    required this.symptom,
    this.fpsLocation,
    this.language,
    required this.onDiagnosisReady,
    required this.onNext,
    required this.onBack,
  });

  @override
  State<Step3Verify> createState() => _Step3VerifyState();
}

class _Step3VerifyState extends State<Step3Verify> {
  _VerifyState _state = _VerifyState.loading;
  String? _errorMessage;
  Diagnosis? _diagnosis;

  @override
  void initState() {
    super.initState();
    _runDiagnosis();
  }

  Future<void> _runDiagnosis() async {
    setState(() {
      _state = _VerifyState.loading;
      _errorMessage = null;
    });

    try {
      final result = await MouApi.instance.diagnose(
        aadhaarImage: widget.aadhaarImage,
        rationCardImage: widget.rationCardImage,
        symptom: widget.symptom,
        fpsLocation: widget.fpsLocation,
        language: widget.language,
      );
      if (!mounted) return;
      setState(() {
        _diagnosis = result;
        _state = _VerifyState.ready;
      });
      widget.onDiagnosisReady(result, null);
    } on UnreadableImageException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.message;
        _state = _VerifyState.unreadable;
      });
      widget.onDiagnosisReady(null, e.message);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.message;
        _state = _VerifyState.error;
      });
      widget.onDiagnosisReady(null, e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Unexpected error: $e';
        _state = _VerifyState.error;
      });
      widget.onDiagnosisReady(null, 'Unexpected error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppText.of(context);
    switch (_state) {
      case _VerifyState.loading:
        return _LoadingView();
      case _VerifyState.unreadable:
        return _ErrorView(
          icon: Icons.image_not_supported_outlined,
          title: t.docUnreadableTitle,
          message: _errorMessage ?? t.docUnreadableMsg,
          actionLabel: t.retakePhotos,
          onAction: widget.onBack,
          isRetake: true,
        );
      case _VerifyState.error:
        return _ErrorView(
          icon: Icons.cloud_off_outlined,
          title: t.serverErrorTitle,
          message: _errorMessage ?? t.networkError,
          actionLabel: t.retry,
          onAction: _runDiagnosis,
          isRetake: false,
        );
      case _VerifyState.ready:
        return _VerifyReadyView(
          diagnosis: _diagnosis!,
          onNext: widget.onNext,
          onBack: widget.onBack,
        );
    }
  }
}

enum _VerifyState { loading, ready, error, unreadable }

// ── Loading ──────────────────────────────────────────────────────────────────

class _LoadingView extends StatefulWidget {
  @override
  State<_LoadingView> createState() => _LoadingViewState();
}

class _LoadingViewState extends State<_LoadingView>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  int _phase = 0;
  // Number of cycling status phrases (see AppStrings.verifyPhases).
  static const _phaseCount = 4;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 2))
      ..repeat();
    // Cycle phases every ~2.5s
    Future.doWhile(() async {
      await Future.delayed(const Duration(milliseconds: 2500));
      if (!mounted) return false;
      setState(() => _phase = (_phase + 1) % _phaseCount);
      return mounted;
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppText.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 80,
              height: 80,
              child: CircularProgressIndicator(
                  color: AppColors.secondary, strokeWidth: 7),
            ),
            const SizedBox(height: 40),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              child: Text(
                t.verifyPhases[_phase],
                key: ValueKey(_phase),
                style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              t.loadingBody,
              style: const TextStyle(
                  fontSize: 16, color: AppColors.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.lock_outline,
                      size: 18, color: AppColors.secondary),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      t.securityNote,
                      style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Error / Unreadable ────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;
  final bool isRetake;

  const _ErrorView({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
    required this.isRetake,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
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
              child: Icon(icon, color: AppColors.error, size: 42),
            ),
            const SizedBox(height: 28),
            Text(title,
                style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary),
                textAlign: TextAlign.center),
            const SizedBox(height: 14),
            Text(message,
                style: const TextStyle(
                    fontSize: 16, color: AppColors.onSurfaceVariant),
                textAlign: TextAlign.center),
            const SizedBox(height: 36),
            ElevatedButton(
              onPressed: onAction,
              style: ElevatedButton.styleFrom(
                  backgroundColor:
                      isRetake ? AppColors.primary : AppColors.secondary),
              child: Text(actionLabel),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Verification UI ───────────────────────────────────────────────────────────

class _VerifyReadyView extends StatelessWidget {
  final Diagnosis diagnosis;
  final VoidCallback onNext;
  final VoidCallback onBack;

  const _VerifyReadyView({
    required this.diagnosis,
    required this.onNext,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppText.of(context);
    final ex = diagnosis.extracted;
    // Mismatch is driven by the backend's deterministic rules (root_cause),
    // not by a Dart-side string compare which would give false positives
    // (e.g. "Rahima Begum" vs "Rahima Begam" — backend may score ≥85).
    final mismatch = diagnosis.rootCause == RootCause.nameMismatch;

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.verifyTitle,
                  style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary),
                ),
                const SizedBox(height: 6),
                Text(
                  t.verifySubtitle,
                  style: const TextStyle(
                      fontSize: 15, color: AppColors.onSurfaceVariant),
                ),
                const SizedBox(height: 24),

                // ── Name comparison card ───────────────────────────────────
                _CompareCard(
                  label: t.nameOnAadhaar,
                  value: ex.aadhaarName.isNotEmpty
                      ? ex.aadhaarName
                      : t.notExtracted,
                  isOk: !mismatch,
                  icon: Icons.badge_outlined,
                ),
                const SizedBox(height: 12),
                _CompareCard(
                  label: t.nameOnRation,
                  value: ex.rationNameRomanized.isNotEmpty
                      ? ex.rationNameRomanized
                      : t.notExtracted,
                  isOk: !mismatch,
                  icon: Icons.receipt_long_outlined,
                ),
                if (ex.rationNameScript.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _ScriptRow(label: t.scriptLabel, value: ex.rationNameScript),
                ],

                // ── Mismatch banner ───────────────────────────────────────
                if (mismatch) ...[
                  const SizedBox(height: 16),
                  _MismatchBanner(),
                ],

                // ── DOB comparison ────────────────────────────────────────
                if (ex.aadhaarDob != null || ex.rationDob != null) ...[
                  const SizedBox(height: 20),
                  Text(t.dobLabel,
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.1,
                          color: AppColors.onSurfaceVariant)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _DobChip(
                            label: t.aadhaarShort,
                            value: ex.aadhaarDob ?? '—'),
                      ),
                      const SizedBox(width: 10),
                      const Icon(Icons.compare_arrows,
                          color: AppColors.outline),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _DobChip(
                            label: t.rationShort,
                            value: ex.rationDob ?? '—'),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 32),

                // ── Confidence tag ────────────────────────────────────────
                _ConfidenceBadge(confidence: diagnosis.confidence),

                const SizedBox(height: 24),

                // ── Disclaimer (FR-20) ─────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: AppColors.outlineVariant, width: 1.5),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline,
                          color: AppColors.primary, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          diagnosis.disclaimer,
                          style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.onSurfaceVariant),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),
              ],
            ),
          ),
        ),

        // ── Bottom actions ────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            border: Border(
                top: BorderSide(color: AppColors.surfaceContainer, width: 2)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onBack,
                      child: Text(t.goBack),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: onNext,
                      style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.secondary),
                      child: Text(t.seeResults),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Small widgets ────────────────────────────────────────────────────────────

class _CompareCard extends StatelessWidget {
  final String label;
  final String value;
  final bool isOk;
  final IconData icon;

  const _CompareCard(
      {required this.label,
      required this.value,
      required this.isOk,
      required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isOk ? AppColors.surfaceContainerLowest : AppColors.errorContainer.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isOk ? AppColors.outlineVariant : AppColors.error.withValues(alpha: 0.5),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon,
                  size: 16,
                  color: isOk ? AppColors.outline : AppColors.error),
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.1,
                      color: isOk
                          ? AppColors.onSurfaceVariant
                          : AppColors.error)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(value,
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isOk ? AppColors.primary : AppColors.error)),
              ),
              Icon(
                isOk ? Icons.check_circle : Icons.error,
                color: isOk ? AppColors.secondary : AppColors.error,
                size: 24,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ScriptRow extends StatelessWidget {
  final String label;
  final String value;

  const _ScriptRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Text('$label: ',
              style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.onSurfaceVariant,
                  fontWeight: FontWeight.w600)),
          Text(value,
              style: const TextStyle(
                  fontSize: 18, color: AppColors.primary)),
        ],
      ),
    );
  }
}

class _MismatchBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.errorContainer.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded,
              color: AppColors.error, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              AppText.of(context).mismatchBanner,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }
}

class _DobChip extends StatelessWidget {
  final String label;
  final String value;

  const _DobChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.onSurfaceVariant,
                  letterSpacing: 0.8)),
          const SizedBox(height: 4),
          Text(value,
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary)),
        ],
      ),
    );
  }
}

class _ConfidenceBadge extends StatelessWidget {
  final Confidence confidence;

  const _ConfidenceBadge({required this.confidence});

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    switch (confidence) {
      case Confidence.high:
        bg = const Color(0xFFD4EDDA);
        fg = const Color(0xFF155724);
        break;
      case Confidence.medium:
        bg = const Color(0xFFFFF3CD);
        fg = const Color(0xFF856404);
        break;
      case Confidence.low:
        bg = const Color(0xFFF8D7DA);
        fg = const Color(0xFF721C24);
        break;
    }
    final label = AppText.of(context).confidenceBadge(confidence);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 13, fontWeight: FontWeight.w700, color: fg)),
    );
  }
}
