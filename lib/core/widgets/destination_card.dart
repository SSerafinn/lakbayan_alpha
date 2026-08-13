import "package:flutter/material.dart";

import "../theme/app_dimens.dart";
import "../theme/app_typography.dart";
import "../theme/lakbayan_colors.dart";
import "lakbayan_badge.dart";

/// The destination card from the design system.
///
/// Photography is the hero and the chrome stays calm: a 16:9 image, a 16dp
/// radius, a hairline border and the soft `elevation.card` shadow — no heavy
/// colour bars. The AR badge sits over the image at top-left when present.
class DestinationCard extends StatelessWidget {
  const DestinationCard({
    required this.town,
    required this.name,
    required this.description,
    this.image,
    this.hasAr = false,
    this.status,
    this.meta,
    this.onTap,
    super.key,
  });

  /// Municipality — rendered as an overline above the name.
  final String town;
  final String name;
  final String description;

  /// The destination photo. Falls back to a placeholder so the card keeps its
  /// shape while an image loads or when offline with a cold cache.
  final Widget? image;

  final bool hasAr;

  /// Short status such as "Open now". Omitted when unknown.
  final String? status;

  /// Secondary metadata such as "2.4 km · 45 min drive".
  final String? meta;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.lakbayan;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: AppRadius.lgAll,
        border: Border.all(color: c.line),
        boxShadow: AppShadow.card,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.lgAll,
          child: ClipRRect(
            borderRadius: AppRadius.lgAll,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  children: [
                    AspectRatio(
                      aspectRatio: 16 / 9,
                      child:
                          image ??
                          const ImagePlaceholder(
                            borderRadius: BorderRadius.zero,
                          ),
                    ),
                    if (hasAr)
                      const Positioned(
                        top: AppSpace.x3,
                        left: AppSpace.x3,
                        child: LakbayanBadge.ar(),
                      ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpace.x4,
                    14,
                    AppSpace.x4,
                    AppSpace.x4,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Overline(town),
                      const SizedBox(height: 6),
                      Text(name, style: AppTypography.h3),
                      const SizedBox(height: 6),
                      Text(description, style: AppTypography.body),
                      if (status != null || meta != null) ...[
                        const SizedBox(height: AppSpace.x3),
                        Row(
                          children: [
                            if (status != null)
                              LakbayanBadge(status!, kind: BadgeKind.neutral),
                            if (status != null && meta != null)
                              const SizedBox(width: AppSpace.x2),
                            if (meta != null)
                              Flexible(
                                child: Text(
                                  meta!,
                                  style: AppTypography.caption,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
