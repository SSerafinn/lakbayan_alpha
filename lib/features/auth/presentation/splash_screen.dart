import "package:flutter/material.dart";

import "../../../core/theme/app_colors.dart";
import "../../../core/theme/app_dimens.dart";
import "../../../core/theme/app_typography.dart";

/// Wireframe 1b · Splash.
///
/// Holds while the session is restored. The wireframe budgets ≤2s and makes the
/// progress bar the only loading affordance — no spinner, no text beyond the
/// wordmark. The router decides where to go next; this screen never navigates.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.green500,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 130,
              height: 130,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                "L",
                style: AppTypography.display.copyWith(
                  color: AppColors.green500,
                  fontSize: 64,
                ),
              ),
            ),
            const SizedBox(height: AppSpace.x6),
            Text(
              "Lakbayan",
              style: AppTypography.h1.copyWith(color: Colors.white),
            ),
            const SizedBox(height: AppSpace.x2),
            Text(
              "Endless Fun, Cagayan",
              style: AppTypography.title.copyWith(
                color: Colors.white.withValues(alpha: 0.85),
              ),
            ),
            const SizedBox(height: AppSpace.x8),
            SizedBox(
              width: 120,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  minHeight: 4,
                  backgroundColor: Colors.white.withValues(alpha: 0.25),
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
