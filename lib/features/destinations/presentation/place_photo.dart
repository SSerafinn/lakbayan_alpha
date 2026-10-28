import "package:flutter/material.dart";
import "package:go_router/go_router.dart";

import "../../../core/models/destination.dart";
import "../../../core/router/app_router.dart";
import "../../../core/theme/app_dimens.dart";
import "../../../core/widgets/content/media_tile.dart";
import "../../../core/widgets/content/storage_image.dart";
import "../../../core/widgets/motion/page_transitions.dart";
import "../domain/practical_text.dart";
import "save_heart.dart";

// This file shows a place as a photo that opens it, and decides what the
// photo says before it is opened.

/// Something a photo of a place can say before it is opened.
enum PlaceTag {
  /// The entry fee, in the editor's short words (`entryPrice`).
  price,

  /// The scan glyph, where there are exhibits to scan (D-18).
  scan,

  /// The flame, where the province marks the place popular.
  popular,
}

/// At most two tags on a photo, each on its own glass, in the order a
/// visitor decides by: what it costs, then what only this app can show, then
/// that it is popular. [hide] drops what the section around the photo says
/// already (no flame inside Popular Destinations, no scan glyph inside Scan
/// Exhibits). Null when there is nothing to say, so a photo carries no empty
/// pill and most photos carry none at all.
Widget? placeTags(
  Destination place, {
  Set<PlaceTag> hide = const {},
  int most = 2,
}) {
  final price = hide.contains(PlaceTag.price) ? null : entryPrice(place);
  final pills = <Widget>[
    // The price is the one with words in it: it shrinks first on a narrow
    // photo, with an ellipsis, rather than pushing the glyph off.
    if (price != null) Flexible(child: PhotoPill(price)),
    if (place.hasAR && !hide.contains(PlaceTag.scan)) const PhotoPill.scan(),
    if (place.popular && !hide.contains(PlaceTag.popular))
      const PhotoPill.popular(),
  ].take(most).toList();
  if (pills.isEmpty) return null;
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (final (index, pill) in pills.indexed) ...[
        if (index > 0) const SizedBox(width: AppSpace.x1),
        pill,
      ],
    ],
  );
}

/// A place as its photo with its name on the scrim; a tap opens its page, the
/// photo zooming from here. What the photo says is [placeTags] unless the
/// caller has its own [pill] (a distance), and the heart sits top trailing
/// where [heart] is set. A small photo turns both off: a narrow tile with a
/// pill and a heart has no room left for the place.
class PlacePhoto extends StatelessWidget {
  const PlacePhoto({
    required this.place,
    required this.from,
    required this.aspectRatio,
    this.town = false,
    this.tags = true,
    this.hide = const {},
    this.pill,
    this.heart = false,
    this.dense = true,
    this.radius = AppRadii.tile,
    this.onOpen,
    super.key,
  });

  final Destination place;

  /// Where the photo is, so it flies from the right copy.
  final HeroSource from;

  final double aspectRatio;

  /// The town as the caption's second line.
  final bool town;

  /// Show [placeTags]; off on a small photo.
  final bool tags;

  /// Tags the section around the photo already says.
  final Set<PlaceTag> hide;

  /// The caller's own note in place of the tags (a distance).
  final Widget? pill;

  /// The save heart, top trailing.
  final bool heart;

  /// A small photo's caption (`MediaTile.dense`).
  final bool dense;

  /// The fallback radius when there is no parent to derive from.
  final double radius;

  /// Called just before the page opens: search folds away.
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) => MediaTile(
    media: PhotoHero(
      tag: coverHeroTag(place.id, from),
      child: CoverImage(place.coverImage),
    ),
    aspectRatio: aspectRatio,
    overlay: true,
    dense: dense,
    radius: radius,
    title: place.name,
    subtitle: town ? place.town : null,
    // A small photo that also carries the heart keeps one tag: beside a
    // 48 heart box, two pills fit only by cutting the price short.
    pill:
        pill ??
        (tags
            ? placeTags(place, hide: hide, most: heart && dense ? 1 : 2)
            : null),
    trailing: heart ? SaveHeart(place.id, style: SaveHeartStyle.tile) : null,
    onTap: () {
      onOpen?.call();
      context.push(Routes.destination(place.id, from: from));
    },
  );
}
