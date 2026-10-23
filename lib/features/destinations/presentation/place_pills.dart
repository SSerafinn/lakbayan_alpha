import "package:flutter/material.dart";

import "../../../core/models/destination.dart";
import "../../../core/theme/app_dimens.dart";
import "../../../core/widgets/content/media_tile.dart";
import "../domain/practical_text.dart";

/// What a photo of a place can say before it is opened: what it costs to get
/// in, when the CMS has a short fee, and the scan glyph where there are
/// exhibits to scan. Each on its own glass, side by side. Null when there is
/// nothing to say, so a photo carries no empty pill.
Widget? placePills(Destination place) {
  final price = entryPrice(place);
  if (price == null && !place.hasAR) return null;
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      if (price != null) PhotoPill(price),
      if (price != null && place.hasAR) const SizedBox(width: AppSpace.x1),
      if (place.hasAR) const PhotoPill.scan(),
    ],
  );
}
