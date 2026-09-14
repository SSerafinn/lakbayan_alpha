import "package:flutter/material.dart";

import "../theme/app_dimens.dart";

/// A card: one logical unit that can be acted on as a whole.
///
/// **Anatomy.** A single child. Media, title, supporting text and actions are
/// the child's business; the card owns the surface, the shape and the tap.
///
/// **Shape.** Concentric with a fallback. Standalone it takes
/// [AppRadii.md]; nested inside a [ParentRadius] it derives its radius from
/// the parent minus [inset], so the gap stays constant around the corner. It
/// provides its own radius downward, so media inside it derives in turn.
///
/// **Surface.** `surfaceContainerLow`, no border, no shadow. A card is one
/// tonal step up from the ground and nothing more (design doc 04).
///
/// **Behaviour.** When [onTap] is set the whole surface is the target, with
/// the platform ripple. Two competing targets inside one card is a design
/// failure, so inner actions should be rare and deliberate.
class AppCard extends StatelessWidget {
  const AppCard({
    required this.child,
    this.onTap,
    this.padding = EdgeInsets.zero,
    this.inset = AppSpace.x2,
    this.color,
    super.key,
  });

  final Widget child;
  final VoidCallback? onTap;

  /// Space between the card edge and the child.
  final EdgeInsetsGeometry padding;

  /// The gap between this card and its parent's edge, when nested. Drives the
  /// concentric radius. Irrelevant when standalone.
  final double inset;

  /// Overrides the surface tier. Stays within the surface ladder.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final radius = concentricOf(context, padding: inset, fallback: AppRadii.md);
    final borderRadius = BorderRadius.circular(radius);
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: color ?? scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: borderRadius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: ParentRadius(
          radius: radius,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}
