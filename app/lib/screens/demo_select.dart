import 'package:flutter/material.dart';

import '../demo/demo_scenarios.dart';
import '../l10n/strings.dart';
import '../theme.dart';

/// Demo scenario picker — shown after "Try Demo" on the welcome screen.
///
/// Picking a scenario does NOT skip any step: the user still selects a
/// language, uploads both documents and walks the full flow.  The scenario is
/// only stored so the diagnosis is deterministic. (See [DemoScenario].)
class DemoSelectScreen extends StatelessWidget {
  final ValueChanged<DemoScenario> onScenarioSelected;

  const DemoSelectScreen({super.key, required this.onScenarioSelected});

  @override
  Widget build(BuildContext context) {
    final t = AppText.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.secondaryContainer,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              t.demoBadge,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                  color: AppColors.onSecondaryContainer),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            t.chooseScenario,
            style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: AppColors.primary),
          ),
          const SizedBox(height: 8),
          Text(
            t.chooseScenarioSub,
            style: const TextStyle(
                fontSize: 15, height: 1.4, color: AppColors.onSurfaceVariant),
          ),
          const SizedBox(height: 24),
          for (final s in kDemoScenarios) ...[
            _ScenarioCard(
              scenario: s,
              name: t.demoScenarioName(s.id),
              description: t.demoScenarioDesc(s.id),
              onTap: () => onScenarioSelected(s),
            ),
            const SizedBox(height: 14),
          ],
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _ScenarioCard extends StatelessWidget {
  final DemoScenario scenario;
  final String name;
  final String description;
  final VoidCallback onTap;

  const _ScenarioCard({
    required this.scenario,
    required this.name,
    required this.description,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.outlineVariant, width: 1.5),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  color: Color(0xFFEEF7F1),
                  shape: BoxShape.circle,
                ),
                child: Icon(scenario.icon,
                    color: AppColors.secondary, size: 26),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary)),
                    const SizedBox(height: 3),
                    Text(description,
                        style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.onSurfaceVariant)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.outline),
            ],
          ),
        ),
      ),
    );
  }
}
