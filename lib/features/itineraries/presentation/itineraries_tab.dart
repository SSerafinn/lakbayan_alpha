import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";

import "../../../core/errors/error_copy.dart";
import "../../../core/errors/local_first.dart";
import "../../../core/models/destination.dart";
import "../../../core/models/itinerary.dart";
import "../../../core/router/app_router.dart";
import "../../../core/theme/app_dimens.dart";
import "../../../core/theme/app_icons.dart";
import "../../../core/theme/app_typography.dart";
import "../../../core/theme/lakbayan_colors.dart";
import "../../../core/widgets/chrome/app_menu.dart";
import "../../../core/widgets/chrome/floating_tab_bar.dart";
import "../../../core/widgets/content/grouped_section.dart";
import "../../../core/widgets/content/media_tile.dart";
import "../../../core/widgets/content/quiet_note.dart";
import "../../../core/widgets/content/section_heading.dart";
import "../../../core/widgets/content/storage_image.dart";
import "../../../core/widgets/controls/symbol_button.dart";
import "../../../core/widgets/motion/motion.dart";
import "../../auth/domain/auth_providers.dart";
import "../../destinations/domain/destination_providers.dart";
import "../domain/itinerary_copy.dart";
import "../domain/itinerary_providers.dart";
import "new_itinerary_sheet.dart";
import "tour_tile.dart";

/// Trips (D-19). **Job:** get back to my plans. **Emotion:** anticipation.
/// The large title and New trip; the next trip large as its photo; the rest
/// as rows on one card; the province tours I kept as posters.
class ItinerariesTab extends ConsumerWidget {
  const ItinerariesTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final signedIn = ref.watch(
      authStateProvider.select((auth) => auth.value != null),
    );
    if (!signedIn) return const _GuestPrompt();

    const gutter = EdgeInsets.symmetric(horizontal: AppSpace.gutter);

    return EntranceScope(
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          0,
          MediaQuery.viewPaddingOf(context).top + AppSpace.x2,
          0,
          FloatingTabBar.clearance(context) + AppSpace.section,
        ),
        children: const [
          Padding(padding: gutter, child: _Title()),
          SizedBox(height: AppSpace.section),
          Padding(
            padding: gutter,
            child: Entrance(order: 1, child: _Mine()),
          ),
          SizedBox(height: AppSpace.section),
          Entrance(order: 2, child: _SavedTours()),
        ],
      ),
    );
  }
}

/// The large title, and beside it the one primary action, New trip, on its
/// emerald circle: beside what it creates, not floating over empty space.
///
/// Signed out, the title stands alone. A guest's one action is Sign In; a
/// New trip they could fill in but never save would end in an error that no
/// retry fixes.
class _Title extends StatelessWidget {
  const _Title({this.canCreate = true});

  final bool canCreate;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.x1),
            child: Semantics(
              header: true,
              child: Text("Trips", style: AppTypography.display),
            ),
          ),
        ),
        if (canCreate)
          SymbolButton(
            icon: AppIcons.add,
            tooltip: "New trip",
            onTap: () => showNewItinerary(context),
            background: scheme.primary,
            color: scheme.onPrimary,
          ),
      ],
    );
  }
}

/// Next up, then the rest on one card.
class _Mine extends ConsumerWidget {
  const _Mine();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shelf = ref.watch(tripShelfProvider);
    return shelf.whenLocalFirst(
      loading: () => const _Loading(),
      error: (e, _) => QuietNote(
        errorCopy("Couldn't load your trips.", e),
        onRetry: () => ref.invalidate(myItinerariesProvider),
      ),
      data: (shelf) {
        final next = shelf.next;
        if (next == null) {
          return const QuietNote(
            "Nothing planned yet. Start a trip with the plus, then add "
            "places from any page.",
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _NextTripCard(trip: next),
            if (shelf.others.isNotEmpty) ...[
              const SizedBox(height: AppSpace.section),
              GroupedSection(
                children: [
                  for (final trip in shelf.others) _ItineraryRow(trip),
                ],
              ),
            ],
          ],
        );
      },
    );
  }
}

/// A trip, its first stop's photo and its name; the photo grows into the
/// trip's route map when it opens (`tripHeroTag`).
class _ItineraryRow extends ConsumerWidget {
  const _ItineraryRow(this.itinerary);

  final Itinerary itinerary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final first = itinerary.destinationIds.firstOrNull;
    final cover = first == null
        ? null
        : ref.watch(destinationByIdProvider(first)).value?.coverImage;
    return GroupedRow(
      title: itinerary.name,
      leading: Hero(tag: tripHeroTag(itinerary.id), child: CoverImage(cover)),
      trailing: GroupedRow.noAccessory,
      onTap: () => context.push(Routes.itinerary(itinerary.id)),
    );
  }
}

/// The province's tours this person kept, as posters. A tap draws one on the
/// map; its menu, from the poster's corner, removes it.
class _SavedTours extends ConsumerWidget {
  const _SavedTours();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saved = ref.watch(savedToursProvider);
    const gutter = EdgeInsets.symmetric(horizontal: AppSpace.gutter);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(padding: gutter, child: SectionHeading("Saved Tours")),
        const SizedBox(height: AppSpace.x2),
        saved.whenLocalFirst(
          loading: () => const _Loading(),
          error: (e, _) => Padding(
            padding: gutter,
            child: QuietNote(
              errorCopy("Couldn't load your saved tours.", e),
              onRetry: () => ref.invalidate(savedToursProvider),
            ),
          ),
          data: (items) => items.isEmpty
              ? const Padding(
                  padding: gutter,
                  child: QuietNote(
                    "Tours you save from the province's list appear here.",
                  ),
                )
              : TourRail(
                  tours: items,
                  trailingFor: (tour) => _TourMenu(tour: tour),
                ),
        ),
      ],
    );
  }
}

/// More, on the poster's corner, opening a menu with the one thing to do to
/// a kept tour that a tap does not: let it go.
class _TourMenu extends ConsumerWidget {
  const _TourMenu({required this.tour});

  final Tour tour;

  Future<void> _remove(BuildContext context, WidgetRef ref) async {
    final uid = ref.read(authStateProvider).value?.uid;
    if (uid == null) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(userProfileRepositoryProvider)
          .setTourSaved(uid, tour.id, saved: false);
    } catch (error) {
      debugPrint("Removing a saved tour failed: $error");
      messenger.showSnackBar(
        const SnackBar(content: Text("Couldn't remove it. Try again.")),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return AppMenu(
      groups: [
        [
          AppMenuItem(
            label: "Remove from Saved",
            icon: AppIcons.delete,
            destructive: true,
            onSelected: () => _remove(context, ref),
          ),
        ],
      ],
      builder: (context, controller) => IconButton(
        icon: const Icon(AppIcons.more, size: AppSize.glyphMd),
        tooltip: "More",
        onPressed: controller.isOpen ? controller.close : controller.open,
        style: IconButton.styleFrom(
          backgroundColor: context.lakbayan.glass,
          foregroundColor: scheme.onSurface,
          fixedSize: const Size.square(AppSize.tileSave),
          shape: const CircleBorder(),
        ),
      ),
    );
  }
}

class _GuestPrompt extends ConsumerWidget {
  const _GuestPrompt();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: EdgeInsets.fromLTRB(
        AppSpace.gutter,
        MediaQuery.viewPaddingOf(context).top + AppSpace.x2,
        AppSpace.gutter,
        FloatingTabBar.clearance(context),
      ),
      children: [
        const _Title(canCreate: false),
        const SizedBox(height: AppSpace.section),
        Text("Plans Need an Account", style: AppTypography.titleMedium),
        const SizedBox(height: AppSpace.x2),
        Text(
          // Says what signing in buys, rather than simply refusing.
          // Browsing and downloading both work without one, so the reason
          // has to be specific or it reads as an arbitrary gate.
          "Trips are kept with your account so they follow you to "
          "another phone. Browsing and downloading a town work without "
          "signing in.",
          style: AppTypography.bodyMedium.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpace.section),
        Pressable(
          child: FilledButton(
            onPressed: () => ref.read(guestModeProvider.notifier).disable(),
            child: const Text("Sign In"),
          ),
        ),
      ],
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: AppSpace.x4),
    child: Center(child: CircularProgressIndicator()),
  );
}

/// The trip that comes next, the largest thing on the tab: its first stop's
/// photo, its dates on a pill, the name large on the scrim with its stops as
/// small photos beside it, so the plan reads as places before it is opened.
/// The photo is the trip's `Hero`: it grows into the route map when tapped.
class _NextTripCard extends ConsumerWidget {
  const _NextTripCard({required this.trip});

  final Itinerary trip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final places = ref.watch(placesByIdProvider);
    final stops = [for (final id in trip.destinationIds) ?places[id]];
    final dates = datePhrase(trip);

    return Pressable(
      child: ClipRRect(
        borderRadius: AppRadii.lgAll,
        child: AspectRatio(
          aspectRatio: 14 / 9,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Hero(
                tag: tripHeroTag(trip.id),
                child: CoverImage(stops.firstOrNull?.coverImage),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: MediaScrim(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Text(
                          trip.name,
                          style: AppTypography.hero.copyWith(
                            color: Colors.white,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (stops.isNotEmpty) ...[
                        const SizedBox(width: AppSpace.x3),
                        _Faces(stops: stops),
                      ],
                    ],
                  ),
                ),
              ),
              if (dates != null)
                Positioned(
                  top: AppSpace.x3,
                  left: AppSpace.x3,
                  child: PhotoPill(dates, glyph: AppIcons.calendar),
                ),
              Material(
                type: MaterialType.transparency,
                child: InkWell(
                  onTap: () => context.push(Routes.itinerary(trip.id)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A trip's first stops as small overlapping photos, the rest as a count.
/// Decoration: the stops are the trip's own page.
class _Faces extends StatelessWidget {
  const _Faces({required this.stops});

  final List<Destination> stops;

  static const _shown = 3;
  static const _side = AppSize.tileSave;
  static const _step = _side - AppSpace.x2;

  @override
  Widget build(BuildContext context) {
    final more = stops.length - _shown;
    final faces = [
      for (final place in stops.take(_shown)) CoverImage(place.coverImage),
      if (more > 0)
        ColoredBox(
          color: Theme.of(context).colorScheme.scrim,
          child: Center(
            child: Text(
              "+$more",
              style: AppTypography.labelSmall.copyWith(color: Colors.white),
            ),
          ),
        ),
    ];
    return ExcludeSemantics(
      child: SizedBox(
        width: _side + (faces.length - 1) * _step,
        height: _side,
        child: Stack(
          children: [
            for (final (index, face) in faces.indexed)
              Positioned(
                left: index * _step,
                child: DecoratedBox(
                  position: DecorationPosition.foreground,
                  decoration: const ShapeDecoration(
                    shape: CircleBorder(
                      side: BorderSide(
                        color: Colors.white,
                        width: AppStroke.bold,
                      ),
                    ),
                  ),
                  child: ClipOval(
                    child: SizedBox.square(dimension: _side, child: face),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
