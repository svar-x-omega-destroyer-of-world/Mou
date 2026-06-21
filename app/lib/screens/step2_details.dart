import 'package:flutter/material.dart';
import '../api/mou_api.dart';
import '../l10n/strings.dart';
import '../theme.dart';

class Step2Details extends StatelessWidget {
  final Symptom? selectedSymptom;
  final String location;
  final bool isAssisted;
  final ValueChanged<Symptom?> onSymptomSelected;
  final ValueChanged<String> onLocationChanged;
  final ValueChanged<bool> onAssistedChanged;
  final VoidCallback onNext;
  final VoidCallback onBack;

  const Step2Details({
    super.key,
    required this.selectedSymptom,
    required this.location,
    required this.isAssisted,
    required this.onSymptomSelected,
    required this.onLocationChanged,
    required this.onAssistedChanged,
    required this.onNext,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppText.of(context);
    // Allow next as long as a symptom is selected (location is optional).
    final bool canContinue = selectedSymptom != null;

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Proxy / Assisted mode (FR-2) ─────────────────────────
                _SectionHeader(title: t.whoIsThisFor),
                const SizedBox(height: 12),
                _ToggleCard(
                  leading: Icons.person,
                  title: t.selfServe,
                  subtitle: t.selfServeSub,
                  isSelected: !isAssisted,
                  onTap: () => onAssistedChanged(false),
                ),
                const SizedBox(height: 10),
                _ToggleCard(
                  leading: Icons.people_alt,
                  title: t.assisted,
                  subtitle: t.assistedSub,
                  isSelected: isAssisted,
                  onTap: () => onAssistedChanged(true),
                ),

                const _Divider(),

                // ── Symptom (FR-3) ────────────────────────────────────────
                _SectionHeader(title: t.whatHappened),
                Text(
                  t.whatHappenedSub,
                  style: const TextStyle(
                      fontSize: 15, color: AppColors.onSurfaceVariant),
                ),
                const SizedBox(height: 14),

                ...Symptom.values.map((s) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _SymptomCard(
                        symptom: s,
                        isSelected: selectedSymptom == s,
                        onTap: () => onSymptomSelected(s),
                      ),
                    )),

                const _Divider(),

                // ── Location (FR-3) ───────────────────────────────────────
                _SectionHeader(title: t.whereHappened),
                const SizedBox(height: 6),
                Text(
                  t.whereHappenedSub,
                  style: const TextStyle(
                      fontSize: 15, color: AppColors.onSurfaceVariant),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  initialValue: location,
                  onChanged: onLocationChanged,
                  decoration: InputDecoration(
                    hintText: t.locationHint,
                    prefixIcon:
                        const Icon(Icons.store, color: AppColors.outline),
                    filled: true,
                    fillColor: AppColors.surfaceContainerLowest,
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide:
                          const BorderSide(color: AppColors.primary, width: 2),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide:
                          const BorderSide(color: AppColors.secondary, width: 3),
                    ),
                  ),
                ),

                if (!canContinue)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: _InfoBanner(message: t.selectToContinue),
                  ),

                const SizedBox(height: 80),
              ],
            ),
          ),
        ),

        // ── Navigation bar ────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            border:
                Border(top: BorderSide(color: AppColors.surfaceContainer, width: 2)),
          ),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onBack,
                  child: Text(t.back),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: canContinue ? onNext : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: canContinue
                        ? AppColors.secondary
                        : AppColors.surfaceContainerHigh,
                    foregroundColor:
                        canContinue ? Colors.white : AppColors.outline,
                  ),
                  child: Text(t.analyse),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Helper widgets ─────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 2),
        child: Text(title,
            style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.primary)),
      );
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(vertical: 22),
        child: Divider(color: AppColors.surfaceContainerHighest, thickness: 2),
      );
}

class _ToggleCard extends StatelessWidget {
  final IconData leading;
  final String title;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  const _ToggleCard(
      {required this.leading,
      required this.title,
      required this.subtitle,
      required this.isSelected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEEF7F1) : AppColors.surfaceContainerLow,
          border: Border.all(
              color: isSelected ? AppColors.secondary : Colors.transparent,
              width: 2.5),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.secondary.withValues(alpha: 0.1)
                    : AppColors.surfaceContainerHighest,
                shape: BoxShape.circle,
              ),
              child: Icon(leading,
                  size: 26,
                  color:
                      isSelected ? AppColors.secondary : AppColors.primary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isSelected
                              ? AppColors.secondary
                              : AppColors.primary)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.onSurfaceVariant)),
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle,
                  color: AppColors.secondary, size: 22),
          ],
        ),
      ),
    );
  }
}

class _SymptomCard extends StatelessWidget {
  final Symptom symptom;
  final bool isSelected;
  final VoidCallback onTap;

  static const _icons = {
    Symptom.turnedAwayAtFps: Icons.block,
    Symptom.cardNotFound: Icons.search_off,
    Symptom.biometricFailed: Icons.fingerprint,
    Symptom.nameNotMatching: Icons.person_search,
    Symptom.other: Icons.help_outline,
  };

  const _SymptomCard(
      {required this.symptom,
      required this.isSelected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = AppText.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEEF7F1) : AppColors.surfaceContainerLow,
          border: Border.all(
              color: isSelected ? AppColors.secondary : Colors.transparent,
              width: 2.5),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.secondary.withValues(alpha: 0.1)
                    : AppColors.surfaceContainerHighest,
                shape: BoxShape.circle,
              ),
              child: Icon(_icons[symptom] ?? Icons.help_outline,
                  size: 24,
                  color:
                      isSelected ? AppColors.secondary : AppColors.primary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                t.symptomLabel(symptom),
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? AppColors.secondary : AppColors.primary),
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle,
                  color: AppColors.secondary, size: 22),
          ],
        ),
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  final String message;
  const _InfoBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.errorContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded,
              color: AppColors.error, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message,
                style: const TextStyle(
                    fontSize: 14, color: AppColors.onErrorContainer)),
          ),
        ],
      ),
    );
  }
}
