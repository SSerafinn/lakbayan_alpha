import "package:flutter/material.dart";

import "../../theme/app_dimens.dart";
import "../../theme/lakbayan_colors.dart";

/// A symbol-only control on its own glass circle, for actions with reliable
/// shorthand (search, back, close) over photography: the circle is the
/// surface between control and photo (design doc 03). An [IconButton]
/// inside, so tooltip, semantics and the 48dp target come from the framework.
///
/// [onGround] is the same control on the paper page (Browse's header), on a
/// white card circle.
class SymbolButton extends StatelessWidget {
  const SymbolButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.size = AppSize.symbolButton,
    this.color,
    this.onGround = false,
    this.background,
    super.key,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final double size;

  /// The glyph colour; defaults to ink.
  final Color? color;
  final bool onGround;

  /// Replaces the circle's fill, for a control that passes from a photo
  /// onto the page and eases between the two ([onGround]'s step, in
  /// motion).
  final Color? background;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return IconButton(
      onPressed: onTap,
      tooltip: tooltip,
      icon: Icon(icon, size: AppSize.glyph),
      style: IconButton.styleFrom(
        backgroundColor:
            background ??
            (onGround ? scheme.surfaceContainerLowest : context.lakbayan.glass),
        foregroundColor: color ?? scheme.onSurface,
        fixedSize: Size.square(size),
        shape: const CircleBorder(),
      ),
    );
  }
}
