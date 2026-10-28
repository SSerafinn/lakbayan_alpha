import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../../core/theme/app_dimens.dart";
import "../../../core/theme/app_icons.dart";
import "../../../core/theme/app_typography.dart";
import "../../itineraries/domain/itinerary_copy.dart";
import "../../profile/domain/settings_providers.dart";

/// The province's notice at the top of Explore: a closure, a typhoon
/// advisory. Written in the CMS's Settings, shown while it is live
/// (`Announcement.isLiveAt`), and gone without a trace otherwise — no
/// space held for it while it loads.
///
/// A white card, like a guide's, with the info glyph in ink: not red, which
/// is CLOSED and errors.
class ProvinceNotice extends ConsumerWidget {
  const ProvinceNotice({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notice = ref.watch(liveAnnouncementProvider);
    if (notice == null) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    // The CMS stores the moment after the last day — the midnight it ends —
    // so the day to name is the one before it.
    final lastDay = notice.until?.subtract(const Duration(milliseconds: 1));

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.gutter,
        0,
        AppSpace.gutter,
        AppSpace.section,
      ),
      child: Material(
        color: scheme.surfaceContainerLowest,
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.mdAll),
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.x3),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(AppIcons.info, color: scheme.onSurface, size: 22),
              const SizedBox(width: AppSpace.x2),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(notice.text.trim(), style: AppTypography.bodyMedium),
                    if (lastDay != null)
                      Text(
                        "Until ${shortDate(lastDay)}",
                        style: AppTypography.secondLine.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
