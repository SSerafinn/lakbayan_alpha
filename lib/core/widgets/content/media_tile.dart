import "package:flutter/material.dart";

import "../../theme/app_dimens.dart";
import "../../theme/app_icons.dart";
import "../../theme/app_typography.dart";
import "../../theme/lakbayan_colors.dart";
import "../motion/motion.dart";

/// A photograph with an optional caption; the tile adds no chrome of its own.
///
/// A [PhotoPill] top leading, [trailing] control top trailing (the save
/// heart), then a caption below the photo or, with [overlay], a title on it
/// over the scrim (the one gradient the app draws). Concentric inside a
/// [ParentRadius], else [radius]. With [onTap] the whole tile is the target
/// and sinks under the finger.
class MediaTile extends StatelessWidget {
  const MediaTile({
    required this.media,
    required this.aspectRatio,
    this.title,
    this.subtitle,
    this.subtitleColor,
    this.pill,
    this.trailing,
    this.overlay = false,
    this.dense = false,
    this.radius = AppRadii.tile,
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

  /// At the top leading corner, on the photo: a [PhotoPill], or a row of
  /// them, each on its own glass.
  final Widget? pill;

  /// A control at the top trailing corner, on its own glass circle. It sits
  /// above the tile's ripple so it is its own tap target.
  final Widget? trailing;

  /// Draw the title on the photo over a scrim instead of below it.
  final bool overlay;

  /// With [overlay]: a small tile's caption, the title a row title rather
  /// than a heading and the scrim shallower, so a rail or a grid of photos
  /// needs no caption space under each one.
  final bool dense;

  /// The fallback radius when there is no parent to derive from.
  final double radius;

  final VoidCallback? onTap;

  /// The gap to the parent edge when nested, for the concentric radius.
  static const _inset = AppSpace.x3;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final resolved = concentricOf(context, padding: _inset, fallback: radius);
    final shape = BorderRadius.circular(resolved);

    final photo = ClipRRect(
      borderRadius: shape,
      child: AspectRatio(
        aspectRatio: aspectRatio,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Its corners, for a photo that flies out of here to unround
            // from (`PhotoHero`).
            ParentRadius(radius: resolved, child: media),
            if (overlay && title != null)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: MediaScrim(
                  padding: dense
                      ? const EdgeInsets.fromLTRB(
                          AppSpace.x2,
                          AppSpace.x8,
                          AppSpace.x2,
                          AppSpace.x2,
                        )
                      : const EdgeInsets.fromLTRB(
                          AppSpace.x4,
                          AppSpace.x12,
                          AppSpace.x4,
                          AppSpace.x4,
                        ),
                  child: _OverlayCaption(
                    title: title!,
                    subtitle: subtitle,
                    dense: dense,
                  ),
                ),
              ),
            // The tap target sits on top of the photo so a press reads on
            // the image, not under it.
            if (onTap != null)
              Material(
                type: MaterialType.transparency,
                child: InkWell(onTap: onTap, borderRadius: shape),
              ),
            // One row, centred on a shared line, so a pill and the heart
            // never sit at different heights. The heart sits above the
            // ripple so it is its own target.
            if (pill != null || trailing != null)
              Positioned(
                top: AppSpace.x2,
                left: AppSpace.x2,
                right: AppSpace.x2,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: pill,
                      ),
                    ),
                    // Pills never touch the heart, however narrow the tile.
                    if (pill != null && trailing != null)
                      const SizedBox(width: AppSpace.x1),
                    ?trailing,
                  ],
                ),
              ),
          ],
        ),
      ),
    );

    if (overlay || title == null) {
      return Pressable(enabled: onTap != null, child: photo);
    }

    final captioned = GestureDetector(
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
    return Pressable(enabled: onTap != null, child: captioned);
  }
}

/// A read-only note on a photo, on its own glass: a distance, a date, a
/// price, or a glyph alone on a circle: the scan glyph where a museum's
/// exhibits can be scanned (D-18), the flame where the province marks a place
/// popular. A status is a glyph or a fact, never a badge word (D-19). Not a
/// target.
class PhotoPill extends StatelessWidget {
  const PhotoPill(String this.label, {this.glyph, super.key})
    : semanticLabel = null;

  const PhotoPill.scan({super.key})
    : label = null,
      glyph = AppIcons.scan,
      semanticLabel = "Exhibits to scan";

  const PhotoPill.popular({super.key})
    : label = null,
      glyph = AppIcons.popular,
      semanticLabel = "Popular";

  final String? label;
  final IconData? glyph;

  /// What a glyph alone says to a screen reader.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final brand = context.lakbayan;
    final text = label;
    final pill = Container(
      constraints: const BoxConstraints(minHeight: AppSize.badge),
      padding: EdgeInsets.symmetric(
        horizontal: text == null ? AppSpace.near : AppSpace.x2,
        vertical: text == null ? AppSpace.near : 0,
      ),
      decoration: ShapeDecoration(
        color: brand.glass,
        shape: text == null ? const CircleBorder() : const StadiumBorder(),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (glyph != null)
            Icon(glyph, size: AppSize.glyphSm, color: brand.onGlass),
          if (glyph != null && text != null) const SizedBox(width: AppSpace.x1),
          if (text != null)
            // Shrinks with a narrow tile rather than overflowing it.
            Flexible(
              child: Text(
                text,
                style: AppTypography.labelMedium.copyWith(color: brand.onGlass),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
    );
    return text == null ? Semantics(label: semanticLabel, child: pill) : pill;
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
  const _OverlayCaption({
    required this.title,
    required this.dense,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: (dense ? AppTypography.titleSmall : AppTypography.titleLarge)
              .copyWith(color: Colors.white),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        if (subtitle != null)
          Text(
            subtitle!,
            style:
                (dense ? AppTypography.secondLine : AppTypography.labelMedium)
                    .copyWith(color: Colors.white),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
      ],
    );
  }
}
