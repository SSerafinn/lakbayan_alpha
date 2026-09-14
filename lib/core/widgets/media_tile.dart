import "package:flutter/material.dart";

import "../theme/app_dimens.dart";
import "../theme/app_typography.dart";
import "lakbayan_badge.dart";

/// A photograph with an optional caption. Photography is the hero; the tile
/// adds no chrome of its own.
///
/// **Anatomy.** Media, badge at the top leading corner (optional), a
/// [trailing] control at the top trailing corner (optional, the save heart),
/// then either a caption *below* the photo (the default) or a title *on* the
/// photo over a scrim ([overlay]).
///
/// **Shape.** Concentric with a fallback of [radius]. Standalone it takes
/// the fallback; inside a [ParentRadius] it derives from the parent.
///
/// **Legibility.** Text never sits directly on a photograph. The caption
/// variant puts it below, on the page surface. The overlay variant draws a
/// bottom scrim from transparent to `scrim` at 70% under the title, tested
/// against a white photo. That scrim is the one gradient this app draws on
/// purpose.
///
/// **Behaviour.** When [onTap] is set the whole tile is the target.
class MediaTile extends StatelessWidget {
  const MediaTile({
    required this.media,
    required this.aspectRatio,
    this.title,
    this.subtitle,
    this.subtitleColor,
    this.badge,
    this.trailing,
    this.overlay = false,
    this.radius = AppRadii.tile,
    this.inset = AppSpace.x3,
    this.onTap,
    super.key,
  });

  /// The photo, sized by the tile. Pass an `ImagePlaceholder` when absent.
  final Widget media;

  /// Width over height. 4/5 for a hero, 3/4 for a rail, 16/10 for a wide
  /// grid cell.
  final double aspectRatio;

  final String? title;
  final String? subtitle;

  /// Colours the caption's second line when it carries a role (a distance).
  final Color? subtitleColor;

  /// Stamped at the top leading corner, on the photo, with its own fill.
  final LakbayanBadge? badge;

  /// A control at the top trailing corner, on its own white circle. It sits
  /// above the tile's ripple so it is its own tap target.
  final Widget? trailing;

  /// Draw the title on the photo over a scrim instead of below it.
  final bool overlay;

  /// The fallback radius when there is no parent to derive from.
  final double radius;

  /// The gap to the parent edge when nested. Drives the concentric radius.
  final double inset;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final resolved = concentricOf(context, padding: inset, fallback: radius);
    final shape = BorderRadius.circular(resolved);

    final photo = ClipRRect(
      borderRadius: shape,
      child: AspectRatio(
        aspectRatio: aspectRatio,
        child: Stack(
          fit: StackFit.expand,
          children: [
            media,
            if (overlay && title != null)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: MediaScrim(
                  child: _OverlayCaption(title: title!, subtitle: subtitle),
                ),
              ),
            // The ripple sits on top of the photo so a tap reads on the
            // image, not under it.
            if (onTap != null)
              Material(
                type: MaterialType.transparency,
                child: InkWell(onTap: onTap, borderRadius: shape),
              ),
            if (badge != null)
              Positioned(top: AppSpace.x3, left: AppSpace.x3, child: badge!),
            if (trailing != null)
              Positioned(
                top: AppSpace.x2,
                right: AppSpace.x2,
                child: trailing!,
              ),
          ],
        ),
      ),
    );

    if (overlay || title == null) return photo;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          photo,
          const SizedBox(height: AppSpace.x2),
          Text(
            title!,
            style: AppTypography.titleSmall,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (subtitle != null)
            Text(
              subtitle!,
              style: AppTypography.secondLine.copyWith(
                color: subtitleColor ?? scheme.onSurfaceVariant,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
    );
  }
}

/// The one gradient this app draws on purpose: transparent to `scrim` at 70%
/// under text laid on a photograph. Ink at 70% clears AA for white text on a
/// white photo; the falloff starts high enough that the title never sits on
/// the thin end of it. Wraps whatever sits over the photo's bottom edge.
class MediaScrim extends StatelessWidget {
  const MediaScrim({
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(
      AppSpace.x4,
      AppSpace.x12,
      AppSpace.x4,
      AppSpace.x4,
    ),
    super.key,
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final scrim = Theme.of(context).colorScheme.scrim;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [scrim.withValues(alpha: 0), scrim.withValues(alpha: 0.7)],
        ),
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

class _OverlayCaption extends StatelessWidget {
  const _OverlayCaption({required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: AppTypography.titleLarge.copyWith(color: Colors.white),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        if (subtitle != null)
          Text(
            subtitle!,
            style: AppTypography.labelMedium.copyWith(color: Colors.white),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
      ],
    );
  }
}
