import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../../core/errors/error_copy.dart";
import "../../../core/errors/local_first.dart";
import "../../../core/theme/app_dimens.dart";
import "../../../core/widgets/chrome/page_title.dart";
import "../../../core/widgets/content/grouped_section.dart";
import "../../../core/widgets/content/quiet_note.dart";
import "../../../core/widgets/content/stop_numeral.dart";
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
    // One short line each: what stopped the camera and what brings it back.
    final note = switch (why) {
      ExhibitsWhy.browse => null,
      ExhibitsWhy.cameraDenied =>
        "Lakbayan can't use the camera. Turn it on in your phone's settings "
            "to scan.",
      ExhibitsWhy.arUnavailable => "Scanning isn't available on this phone.",
      ExhibitsWhy.notOnPhone =>
        "${place == null ? "Download this town" : "Download ${place.town}"} "
            "or go online to scan.",
    };

    return EntranceScope(
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: CustomScrollView(
            slivers: [
              const SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  AppSpace.gutter,
                  AppSpace.x2,
                  AppSpace.gutter,
                  AppSpace.section,
                ),
                sliver: SliverToBoxAdapter(child: PageTitle("Exhibits")),
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
