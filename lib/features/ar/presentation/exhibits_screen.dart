import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../../core/errors/error_copy.dart";
import "../../../core/errors/local_first.dart";
import "../../../core/router/app_router.dart";
import "../../../core/theme/app_dimens.dart";
import "../../../core/theme/app_icons.dart";
import "../../../core/theme/app_typography.dart";
import "../../../core/widgets/content/grouped_section.dart";
import "../../../core/widgets/content/quiet_note.dart";
import "../../../core/widgets/content/stop_numeral.dart";
import "../../../core/widgets/controls/symbol_button.dart";
import "../../../core/widgets/motion/motion.dart";
import "../../audio/domain/audio_providers.dart";
import "../../destinations/domain/destination_providers.dart";
import "../domain/ar_providers.dart";
import "exhibit_sheet.dart";

/// Why the exhibits are a list rather than the camera. Travels in the URL.
enum ExhibitsWhy {
  /// Chosen: See all, or a phone that cannot scan, whose page says so.
  browse,
  cameraDenied,
  arUnavailable,

  /// The marker images are neither downloaded nor reachable.
  notOnPhone,
}

/// A museum's exhibits without the camera (D-18): every phone gets them,
/// whatever it can scan. A row opens the same sheet a scan does.
class ExhibitsScreen extends ConsumerWidget {
  const ExhibitsScreen({
    required this.destinationId,
    this.why = ExhibitsWhy.browse,
    super.key,
  });

  final String destinationId;
  final ExhibitsWhy why;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The narration's player lives as long as the screen it was started
    // from; without a listener it would go with the sheet.
    ref.listen(audioGuideControllerProvider, (_, _) {});
    final place = ref.watch(destinationByIdProvider(destinationId)).value;
    final exhibits = ref.watch(destinationExhibitsProvider(destinationId));
    final note = switch (why) {
      ExhibitsWhy.browse => null,
      ExhibitsWhy.cameraDenied =>
        "Lakbayan can't use the camera, so here are the exhibits as a list. "
            "Camera access can be turned on in your phone's settings.",
      ExhibitsWhy.arUnavailable =>
        "Scanning isn't working on this phone right now, so here are the "
            "exhibits as a list.",
      ExhibitsWhy.notOnPhone =>
        "The photos the camera looks for aren't on this phone yet. "
            "${place == null ? "Download this town" : "Download ${place.town}"} "
            "or connect to the internet to scan. Here are the exhibits as a "
            "list until then.",
    };

    return EntranceScope(
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpace.gutter,
                  AppSpace.x2,
                  AppSpace.gutter,
                  AppSpace.section,
                ),
                sliver: SliverToBoxAdapter(
                  child: _Header(placeName: place?.name),
                ),
              ),
              if (note != null)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpace.gutter,
                    0,
                    AppSpace.gutter,
                    AppSpace.x4,
                  ),
                  sliver: SliverToBoxAdapter(child: QuietNote(note)),
                ),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  AppSpace.gutter,
                  0,
                  AppSpace.gutter,
                  MediaQuery.viewPaddingOf(context).bottom + AppSpace.section,
                ),
                sliver: exhibits.whenLocalFirst(
                  loading: () => const SliverToBoxAdapter(
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (error, _) => SliverToBoxAdapter(
                    child: QuietNote(
                      errorCopy("Couldn't load the exhibits.", error),
                      onRetry: () => ref.invalidate(
                        destinationExhibitsProvider(destinationId),
                      ),
                    ),
                  ),
                  data: (items) => items.isEmpty
                      ? const SliverToBoxAdapter(
                          child: QuietNote("No exhibits here yet."),
                        )
                      : SliverGroupedSection(
                          itemCount: items.length,
                          itemBuilder: (context, index) {
                            final exhibit = items[index];
                            return Entrance(
                              order: index,
                              child: GroupedRow(
                                key: ValueKey("exhibit-${exhibit.id}"),
                                title: exhibit.title,
                                subtitle: exhibit.description,
                                mark: StopNumeral(index + 1),
                                trailing: GroupedRow.noAccessory,
                                onTap: () => showExhibitSheet(
                                  context,
                                  destinationId: destinationId,
                                  exhibit: exhibit,
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.placeName});

  final String? placeName;

  @override
  Widget build(BuildContext context) {
    final placeName = this.placeName;
    return Row(
      children: [
        SymbolButton(
          icon: AppIcons.back,
          tooltip: "Back",
          onTap: () => context.popOrHome(),
        ),
        const SizedBox(width: AppSpace.x2),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("Exhibits", style: AppTypography.titleLarge),
              if (placeName != null)
                Text(
                  placeName,
                  style: AppTypography.bodyMedium.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
      ],
    );
  }
}
