import "dart:math" as math;

import "package:flutter/material.dart";

import "../../theme/app_dimens.dart";
import "../../theme/app_typography.dart";
import "../../theme/lakbayan_colors.dart";

/// A stop's place in a route, drawn the same wherever the route appears: the
/// pin on a map and the row in a list, so the eye can match the two (a
/// spatial-blue circle, white numeral, white ring).
///
/// Grows with the user's text size so the numeral never spills out of it.
/// Decorative to a screen reader: the row or pin around it says "Stop 2".
class StopNumeral extends StatelessWidget {
  const StopNumeral(
    this.number, {
    this.size = AppSize.stopNumeral,
    this.ring = AppStroke.bold,
    this.color,
    super.key,
  });

  final int number;
  final double size;
  final double ring;

  /// Defaults to the spatial role; a saved place's pin passes the primary.
  final Color? color;

  /// The circle's side at the user's text size, so a row can keep an empty
  /// slot exactly as wide as a filled one.
  static double sideOf(
    BuildContext context, {
    double size = AppSize.stopNumeral,
    double ring = AppStroke.bold,
  }) {
    final text = MediaQuery.textScalerOf(context)
        .scale(AppTypography.labelMedium.fontSize!);
    return math.max(size, text + AppSpace.x2 + ring * 2);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = AppTypography.labelMedium.copyWith(
      color: scheme.surface,
      height: 1,
    );
    final side = sideOf(context, size: size, ring: ring);

    return ExcludeSemantics(
      child: Container(
        width: side,
        height: side,
        decoration: ShapeDecoration(
          color: color ?? context.lakbayan.spatial,
          shape: CircleBorder(
            side: BorderSide(color: scheme.surface, width: ring),
          ),
        ),
        alignment: Alignment.center,
        child: Text("$number", style: style, maxLines: 1),
      ),
    );
  }
}
