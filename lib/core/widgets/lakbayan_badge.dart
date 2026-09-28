import "package:flutter/material.dart";

import "../theme/app_dimens.dart";
import "../theme/app_typography.dart";
import "../theme/lakbayan_colors.dart";

/// Which meaning a [LakbayanBadge] carries.
///
/// Every badge is a solid, high-contrast capsule with an all-caps label, so
/// it reads at a glance on a photo and on white alike. Colour is one of the
/// signals, never the only one: the label says what the colour means.
///
/// Gold is reserved for [featured]. The design system is explicit that gold
/// never signals status, so there is deliberately no gold "warning" case.
enum BadgeKind {
  /// Solid ink, white text. This destination has AR content. Blue stays
  /// spatial for text and glyphs; on a photo the ink capsule reads first.
  ar,

  /// Solid deep gold, white text. Editorially promoted.
  featured,

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

  const LakbayanBadge.ar({super.key}) : label = "AR", kind = BadgeKind.ar;

  const LakbayanBadge.featured({super.key})
    : label = "Featured",
      kind = BadgeKind.featured;

  final String label;
  final BadgeKind kind;

  @override
  Widget build(BuildContext context) {
    final c = context.lakbayan;
    final scheme = Theme.of(context).colorScheme;

    final (Color fill, Color text, Color? side) = switch (kind) {
      BadgeKind.ar => (scheme.onSurface, scheme.surface, null),
      BadgeKind.featured => (c.featured, c.onFeatured, null),
      BadgeKind.neutral => (
        scheme.surface,
        c.textOnLightGreen,
        scheme.outlineVariant,
      ),
      BadgeKind.info => (
        scheme.surface,
        scheme.onSurface,
        scheme.outlineVariant,
      ),
      BadgeKind.closed => (scheme.error, scheme.onError, null),
    };

    return Container(
      height: AppSize.badge,
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
      // label. widthFactor pins the width to the child.
      child: Center(
        widthFactor: 1,
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
