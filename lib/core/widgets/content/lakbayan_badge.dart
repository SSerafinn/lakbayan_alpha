import "package:flutter/material.dart";

import "../../theme/app_dimens.dart";
import "../../theme/app_typography.dart";
import "../../theme/lakbayan_colors.dart";

/// Which meaning a [LakbayanBadge] carries.
///
/// A capsule with an all-caps label; colour is one of the signals, never
/// the only one. On a photo a status is a `PhotoPill` glyph instead, and
/// featured is position, not a word (D-19). These three last until their
/// screens move.
enum BadgeKind {
  /// White with a hairline, green text. Open now, downloaded, available.
  neutral,

  /// White with a hairline, ink text. Factual metadata such as distance.
  info,

  /// Solid red, white text. Closed, failed, unavailable.
  closed,
}

/// A read-only annotation stamped on a photo, a card or a row.
///
/// 24dp capsule, all caps, 11/800 with wide tracking. Distinct from a [Chip],
/// which is interactive and 38dp tall. A badge never receives a tap. The
/// label always says what the colour means.
class LakbayanBadge extends StatelessWidget {
  const LakbayanBadge(this.label, {required this.kind, super.key});

  final String label;
  final BadgeKind kind;

  @override
  Widget build(BuildContext context) {
    final c = context.lakbayan;
    final scheme = Theme.of(context).colorScheme;
    final card = scheme.surfaceContainerLowest;

    final (Color fill, Color text, Color? side) = switch (kind) {
      BadgeKind.neutral => (card, c.textOnLightGreen, scheme.outlineVariant),
      BadgeKind.info => (card, scheme.onSurface, scheme.outlineVariant),
      BadgeKind.closed => (scheme.error, scheme.onError, null),
    };

    // At least the badge height, taller only when a large text size needs
    // it, so the label is never clipped.
    return Container(
      constraints: const BoxConstraints(minHeight: AppSize.badge),
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.x3),
      decoration: ShapeDecoration(
        color: fill,
        shape: side == null
            ? capsule
            : StadiumBorder(side: BorderSide(color: side)),
      ),
      // `Center(widthFactor: 1)` rather than `Container(alignment:)`: a
      // Container with an alignment expands to fill its loose constraints, so
      // the badge would stretch to the full row width instead of hugging its
      // label. The factors pin the size to the child; the min height and the
      // capsule's padding do the rest.
      child: Center(
        widthFactor: 1,
        heightFactor: 1,
        child: Text(
          label.toUpperCase(),
          style: AppTypography.caps.copyWith(color: text),
        ),
      ),
    );
  }
}

/// Rounded placeholder used wherever a photo has not loaded yet. Mirrors the
/// diagonal hatch the specimen uses to mark image slots.
class ImagePlaceholder extends StatelessWidget {
  const ImagePlaceholder({
    this.height,
    this.width,
    this.borderRadius,
    super.key,
  });

  final double? height;
  final double? width;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: width,
      // A flat surface tier, not a gradient: a placeholder is a photo that has
      // not arrived, and the space should read as quiet rather than decorated.
      decoration: BoxDecoration(
        borderRadius: borderRadius ?? AppRadii.smAll,
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
    );
  }
}
