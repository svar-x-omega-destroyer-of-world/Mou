import 'package:flutter/material.dart';
import '../l10n/strings.dart';
import '../theme.dart';

/// Step 0 — the very first screen.  Branding + the two entry points:
///   • Live Verification — the real flow, using the user's own documents.
///   • Try Demo — the same complete flow, but with a deterministic, polished
///     result chosen up front (presentation-safe for the hackathon).
class WelcomeScreen extends StatelessWidget {
  final VoidCallback onGetStarted;
  final VoidCallback onTryDemo;

  const WelcomeScreen({
    super.key,
    required this.onGetStarted,
    required this.onTryDemo,
  });

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
            // ── Live Verification — primary, real flow ──────────────────────
            ElevatedButton.icon(
              onPressed: onGetStarted,
              icon: const Icon(Icons.verified_user_outlined),
              label: Text(t.liveVerification),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.secondary,
                  foregroundColor: Colors.white),
            ),
            const SizedBox(height: 6),
            Text(
              t.liveVerificationSub,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 13, color: AppColors.onSurfaceVariant),
            ),
            const SizedBox(height: 18),
            // ── Try Demo — same flow, deterministic result ──────────────────
            OutlinedButton.icon(
              onPressed: onTryDemo,
              icon: const Icon(Icons.play_circle_outline),
              label: Text(t.tryDemo),
            ),
            const SizedBox(height: 6),
            Text(
              t.tryDemoSub,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 13, color: AppColors.onSurfaceVariant),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
