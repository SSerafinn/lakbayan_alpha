import "package:flutter/material.dart";

import "../../router/app_router.dart";
import "../../theme/app_dimens.dart";
import "../../theme/app_icons.dart";
import "../../theme/app_typography.dart";
import "../controls/symbol_button.dart";

/// One line of secondary text where a list would be: the empty and error
/// states of a section. [centered] fills the space it is given instead, for
/// a section that is the whole screen.
class QuietNote extends StatelessWidget {
  const QuietNote(this.text, {this.centered = false, super.key});

  final String text;
  final bool centered;

  @override
  Widget build(BuildContext context) {
    final note = Text(
      text,
      style: AppTypography.bodyMedium.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      textAlign: centered ? TextAlign.center : null,
    );
    return centered
        ? Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpace.x8),
              child: note,
            ),
          )
        : Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpace.x2),
            child: note,
          );
  }
}

/// A whole pushed screen reduced to a message: back, then the text. For a
/// route whose subject failed to load or no longer exists.
class MessageScreen extends StatelessWidget {
  const MessageScreen(this.text, {super.key});

  final String text;

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
          Expanded(child: QuietNote(text, centered: true)),
        ],
      ),
    ),
  );
}
