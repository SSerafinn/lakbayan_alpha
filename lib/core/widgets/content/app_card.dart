import "package:flutter/material.dart";

import "../../theme/app_dimens.dart";
import "../motion/motion.dart";

/// A card: one logical unit that can be acted on as a whole.
///
/// **Anatomy.** A single child. Media, title, supporting text and actions are
/// the child's business; the card owns the surface, the shape and the tap.
///
/// **Shape.** Fixed [AppRadii.md]. A card never sits in a card (a grouped
/// plate holds rows, not cards); it provides its radius downward, so media
/// inside it derives in turn.
///
/// **Surface.** `surfaceContainerLowest`, white on the paper ground, no
/// border, no shadow (design doc 04).
///
/// **Behaviour.** When [onTap] is set the whole surface is the target, and
/// it sinks under the finger ([Pressable]). Two competing targets inside one card is a design
/// failure, so inner actions should be rare and deliberate.
class AppCard extends StatelessWidget {
  const AppCard({
    required this.child,
    this.onTap,
    this.padding = EdgeInsets.zero,
    this.color,
    super.key,
  });

  final Widget child;
  final VoidCallback? onTap;

  /// Space between the card edge and the child.
  final EdgeInsetsGeometry padding;

  /// Overrides the surface tier. Stays within the surface ladder.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final card = Material(
      color: color ?? scheme.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(borderRadius: AppRadii.mdAll),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: ParentRadius(
          radius: AppRadii.md,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
    return Pressable(enabled: onTap != null, child: card);
  }
}
