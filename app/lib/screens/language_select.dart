import 'package:flutter/material.dart';
import '../l10n/strings.dart';
import '../theme.dart';

/// Step 1 — language selection.  This is the FIRST interactive step, before any
/// document upload, so every later screen (instructions, verification, results)
/// renders in the chosen language.
///
/// Tapping a language updates app state immediately (the whole app re-renders
/// via [AppText]); "Continue" is enabled only once a language is chosen.
class LanguageSelectScreen extends StatelessWidget {
  final String? selectedLanguage;
  final ValueChanged<String> onLanguageSelected;
  final VoidCallback onContinue;

  const LanguageSelectScreen({
    super.key,
    required this.selectedLanguage,
    required this.onLanguageSelected,
    required this.onContinue,
  });

  // Native labels stay in their own script regardless of the active language.
  static const _options = [
    (code: 'en', label: 'English', flag: '🇬🇧'),
    (code: 'hi', label: 'हिन्दी (Hindi)', flag: '🇮🇳'),
    (code: 'bn', label: 'বাংলা (Bengali)', flag: '🇧🇩'),
  ];

  @override
  Widget build(BuildContext context) {
    final t = AppText.of(context);
    final bool canContinue = selectedLanguage != null;

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                Text(
                  t.chooseLanguage,
                  style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary),
                ),
                const SizedBox(height: 10),
                Text(
                  t.chooseLanguageSub,
                  style: const TextStyle(
                      fontSize: 16, color: AppColors.onSurfaceVariant),
                ),
                const SizedBox(height: 28),
                for (final o in _options) ...[
                  _LangCard(
                    label: o.label,
                    flag: o.flag,
                    isSelected: selectedLanguage == o.code,
                    onTap: () => onLanguageSelected(o.code),
                  ),
                  const SizedBox(height: 12),
                ],
              ],
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            border: Border(
                top: BorderSide(color: AppColors.surfaceContainer, width: 2)),
          ),
          child: ElevatedButton.icon(
            onPressed: canContinue ? onContinue : null,
            icon: const Icon(Icons.arrow_forward),
            label: Text(t.continueLabel),
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  canContinue ? AppColors.secondary : AppColors.surfaceContainerHigh,
              foregroundColor: canContinue ? Colors.white : AppColors.outline,
            ),
          ),
        ),
      ],
    );
  }
}

class _LangCard extends StatelessWidget {
  final String label;
  final String flag;
  final bool isSelected;
  final VoidCallback onTap;

  const _LangCard({
    required this.label,
    required this.flag,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          color:
              isSelected ? const Color(0xFFEEF7F1) : AppColors.surfaceContainerLow,
          border: Border.all(
              color: isSelected ? AppColors.secondary : Colors.transparent,
              width: 2.5),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Text(flag, style: const TextStyle(fontSize: 26)),
            const SizedBox(width: 16),
            Text(label,
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? AppColors.secondary : AppColors.primary)),
            const Spacer(),
            if (isSelected)
              const Icon(Icons.check_circle,
                  color: AppColors.secondary, size: 24),
          ],
        ),
      ),
    );
  }
}
