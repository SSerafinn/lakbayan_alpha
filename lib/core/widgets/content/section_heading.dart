import "package:flutter/material.dart";

import "../../theme/app_dimens.dart";
import "../../theme/app_typography.dart";

/// A section heading, one or two words in Title Case, with an optional
/// emerald "See All" on the right. No eyebrow above it: the heading is the
/// whole label (D-19).
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
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.x2),
            textStyle: AppTypography.labelMedium,
          ),
          child: const Text("See All"),
        ),
    ],
  );
}
