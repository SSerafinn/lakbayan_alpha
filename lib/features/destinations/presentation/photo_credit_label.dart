import "package:flutter/material.dart";

import "../../../core/theme/app_dimens.dart";
import "../../../core/theme/app_typography.dart";
import "../../../core/theme/lakbayan_colors.dart";

/// A photo's credit, the line `photoCreditLine` makes: small, quiet, and
/// wrapping rather than truncating. An attribution cut off after the name has
/// lost its licence, which is the half the licence asks for.
///
/// [onPhoto] puts it on its own glass, for a photo it sits on, as the map's
/// credit sits on the tiles (`StillMapCredit`). A fixed radius rather than a
/// capsule, because a long credit takes two lines on a narrow phone.
class PhotoCreditLabel extends StatelessWidget {
  const PhotoCreditLabel(
    this.line, {
    this.onPhoto = false,
    this.textAlign = TextAlign.end,
    super.key,
  });

  final String line;
  final bool onPhoto;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    final text = Semantics(
      // "Photo: mkirader, CC BY 2.0" rather than a spoken slash.
      label: line.replaceAll(" / ", ", "),
      excludeSemantics: true,
      child: Text(
        line,
        textAlign: textAlign,
        style: AppTypography.labelSmall.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
    if (!onPhoto) return text;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.lakbayan.glass,
        borderRadius: AppRadii.xsAll,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.x2,
          vertical: AppSpace.x1,
        ),
        child: text,
      ),
    );
  }
}
