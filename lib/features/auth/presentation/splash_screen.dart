import "package:flutter/material.dart";

import "../../../core/theme/app_dimens.dart";
import "../../../core/theme/app_typography.dart";

/// Wireframe 1b · Splash.
///
/// Holds while the session is restored. The wireframe budgets two seconds and
/// makes the progress bar the only loading affordance: no spinner, no text
/// beyond the wordmark. The router decides where to go next; this screen never
/// navigates.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surface,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "LAKBAYAN",
              style: AppTypography.brandWordmark.copyWith(
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: AppSpace.x8),
            SizedBox(
              width: AppSize.progressBar,
              child: ClipRRect(
                borderRadius: capsuleRadius,
                child: LinearProgressIndicator(
                  minHeight: 3,
                  backgroundColor: scheme.outlineVariant,
                  valueColor: AlwaysStoppedAnimation<Color>(scheme.primary),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
