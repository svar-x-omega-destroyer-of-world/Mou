import 'package:flutter/material.dart';
import '../l10n/strings.dart';
import '../theme.dart';

/// Step 0 — the very first screen.  Branding + a single call to action that
/// leads into language selection (which must happen before any document upload).
class WelcomeScreen extends StatelessWidget {
  final VoidCallback onGetStarted;

  const WelcomeScreen({super.key, required this.onGetStarted});

  @override
  Widget build(BuildContext context) {
    final t = AppText.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Spacer(flex: 2),
            Container(
              padding: const EdgeInsets.all(22),
              decoration: const BoxDecoration(
                color: Color(0xFFEEF7F1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.fact_check_outlined,
                  size: 72, color: AppColors.secondary),
            ),
            const SizedBox(height: 28),
            Text(
              t.appName,
              style: const TextStyle(
                  fontSize: 44,
                  fontWeight: FontWeight.w900,
                  color: AppColors.primary,
                  letterSpacing: -1),
            ),
            const SizedBox(height: 14),
            Text(
              t.welcomeTagline,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  height: 1.4,
                  color: AppColors.primary),
            ),
            const SizedBox(height: 16),
            Text(
              t.welcomeBody,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 16, height: 1.5, color: AppColors.onSurfaceVariant),
            ),
            const Spacer(flex: 3),
            ElevatedButton.icon(
              onPressed: onGetStarted,
              icon: const Icon(Icons.arrow_forward),
              label: Text(t.getStarted),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.secondary,
                  foregroundColor: Colors.white),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
