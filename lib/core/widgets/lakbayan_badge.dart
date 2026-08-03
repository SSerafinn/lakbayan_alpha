import "package:flutter/material.dart";

import "../theme/app_dimens.dart";
import "../theme/app_typography.dart";
import "../theme/lakbayan_colors.dart";

/// Which meaning a [LakbayanBadge] carries.
///
/// Gold is reserved for [ar] and [featured]. The design system is explicit that
/// gold never signals status, so there is deliberately no gold "warning" case —
/// use [closed] or [neutral] instead of reaching for the accent.
enum BadgeKind {
  /// Solid gold — this destination has AR content.
  ar,

  /// Soft gold — editorially promoted.
  featured,

  /// Green tint — open now, downloaded, available.
  neutral,

  /// Blue tint — factual metadata such as distance.
  info,

  /// Red tint — closed, failed, unavailable.
  closed,
}

/// The small pill-less badge from the design system: 24dp tall, 6dp radius.
///
/// Distinct from a [Chip], which is interactive, pill-shaped and 36dp tall.
/// Badges are read-only annotations stamped on cards and rows.
class LakbayanBadge extends StatelessWidget {
  const LakbayanBadge(this.label, {required this.kind, super.key});

  const LakbayanBadge.ar({super.key})
      : label = "AR",
        kind = BadgeKind.ar;

  const LakbayanBadge.featured({super.key})
      : label = "FEATURED",
        kind = BadgeKind.featured;

  final String label;
  final BadgeKind kind;

  @override
  Widget build(BuildContext context) {
    final c = context.lakbayan;

    final (Color fill, Color text) = switch (kind) {
      BadgeKind.ar => (c.gold, const Color(0xFF1E2733)),
      BadgeKind.featured => (c.goldContainer, c.goldText),
      BadgeKind.neutral => (c.badgeNeutralFill, c.badgeNeutralText),
      BadgeKind.info => (c.blueTint, const Color(0xFF0C4A7C)),
      BadgeKind.closed => (c.badgeErrorFill, c.badgeErrorText),
    };

    // AR and FEATURED are set in caps with wide tracking; status badges are not.
    final isAccent = kind == BadgeKind.ar || kind == BadgeKind.featured;

    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        isAccent ? label.toUpperCase() : label,
        style: AppTypography.caption.copyWith(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          fontVariations: const [FontVariation("wght", 600)],
          letterSpacing: isAccent ? 1.2 : 0.6,
          height: 1,
          color: text,
        ),
      ),
    );
  }
}

/// Section label — 12sp, semibold, uppercase, +1.2 tracking.
class Overline extends StatelessWidget {
  const Overline(this.text, {this.color, super.key});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) => Text(
        text.toUpperCase(),
        style: AppTypography.overline.copyWith(
          color: color ?? context.lakbayan.textSecondary,
        ),
      );
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
    final c = context.lakbayan;
    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        borderRadius: borderRadius ?? AppRadius.mdAll,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [c.greenSubtle, c.greenTint],
        ),
      ),
    );
  }
}
