import "package:flutter/material.dart";

import "../theme/app_dimens.dart";
import "../theme/app_typography.dart";
import "../theme/lakbayan_colors.dart";

/// A section heading in sentence case, with an optional "See all" in spatial
/// blue on the right. No eyebrow above it: the heading is the whole label.
class SectionHeading extends StatelessWidget {
  const SectionHeading(this.title, {this.onSeeAll, super.key});

  final String title;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          title,
          style: AppTypography.titleMedium,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      if (onSeeAll != null)
        TextButton(
          onPressed: onSeeAll,
          style: TextButton.styleFrom(
            foregroundColor: context.lakbayan.spatial,
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.x2),
          ),
          child: const Text("See all"),
        ),
    ],
  );
}
