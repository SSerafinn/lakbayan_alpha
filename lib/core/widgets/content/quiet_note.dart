import "package:flutter/material.dart";

import "../../router/app_router.dart";
import "../../theme/app_dimens.dart";
import "../../theme/app_icons.dart";
import "../../theme/app_typography.dart";
import "../controls/symbol_button.dart";

/// One line of secondary text where a list would be: the empty and error
/// states of a section. [centered] fills the space it is given instead, for
/// a section that is the whole screen.
///
/// [onRetry] adds Try again under the text, for a failure another attempt
/// may fix. A text button, the theme's tertiary: trying again is never the
/// screen's primary action, so it takes neither the solid green nor, ever,
/// the gold.
class QuietNote extends StatelessWidget {
  const QuietNote(this.text, {this.centered = false, this.onRetry, super.key});

  final String text;
  final bool centered;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final retry = onRetry;
    final Widget note = Text(
      text,
      style: AppTypography.bodyMedium.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      textAlign: centered ? TextAlign.center : null,
    );
    final body = retry == null
        ? note
        : Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: centered
                ? CrossAxisAlignment.center
                : CrossAxisAlignment.start,
            children: [
              note,
              TextButton(
                onPressed: retry,
                // Inline, flush with the text it answers, as The story's
                // Continue reading is.
                style: centered
                    ? null
                    : TextButton.styleFrom(padding: EdgeInsets.zero),
                child: const Text("Try again"),
              ),
            ],
          );
    return centered
        ? Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpace.x8),
              child: body,
            ),
          )
        : Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpace.x2),
            child: body,
          );
  }
}

/// A whole pushed screen reduced to a message: back, then the text. For a
/// route whose subject failed to load or no longer exists, and for a link
/// to nowhere. [onRetry] as on [QuietNote].
class MessageScreen extends StatelessWidget {
  const MessageScreen(this.text, {this.onRetry, super.key});

  final String text;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpace.x2),
            child: SymbolButton(
              icon: AppIcons.back,
              tooltip: "Back",
              onTap: context.popOrHome,
            ),
          ),
          Expanded(child: QuietNote(text, centered: true, onRetry: onRetry)),
        ],
      ),
    ),
  );
}
