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
import "../../../core/widgets/content/lakbayan_badge.dart";
import "../../../core/widgets/content/media_tile.dart";
import "../../../core/widgets/content/quiet_note.dart";
import "../../../core/widgets/content/section_heading.dart";
import "../../../core/widgets/content/stop_numeral.dart";
import "../../../core/widgets/content/storage_image.dart";
import "../../../core/widgets/motion/motion.dart";
import "../../auth/domain/auth_providers.dart";
import "../../destinations/domain/destination_providers.dart";
import "../domain/itinerary_copy.dart";
import "../domain/itinerary_providers.dart";
import "new_itinerary_sheet.dart";
import "tour_tile.dart";

/// The Itineraries tab: my trips and a New itinerary action, plus saved
/// province tours below.
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

/// The title, and beside it the one primary action New itinerary: a tinted
/// glyph beside the content it creates, not floating over empty space.
class _Title extends StatelessWidget {
  const _Title();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(child: Text("Itineraries", style: AppTypography.titleLarge)),
        IconButton(
          onPressed: () => showNewItinerary(context),
          tooltip: "New itinerary",
          icon: const Icon(AppIcons.add),
          style: IconButton.styleFrom(foregroundColor: scheme.primary),
        ),
      ],
    );
  }
}

/// Next up, then the rest.
class _Mine extends ConsumerWidget {
  const _Mine();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shelf = ref.watch(tripShelfProvider);
    return shelf.whenLocalFirst(
      loading: () => const _Loading(),
      error: (e, _) => QuietNote(
        errorCopy("Couldn't load your itineraries.", e),
        onRetry: () => ref.invalidate(myItinerariesProvider),
      ),
      data: (shelf) {
        final next = shelf.next;
        if (next == null) {
          return const QuietNote(
            "Nothing planned yet. Start one with New itinerary, then add "
            "stops from any place.",
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _NextTripCard(trip: next),
            if (shelf.others.isNotEmpty) ...[
              const SizedBox(height: AppSpace.section),
              const SectionHeading("Other trips"),
              const SizedBox(height: AppSpace.x2),
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

/// A trip, led by its first stop's photo, which grows into the trip's route
/// map when it opens (`tripHeroTag`).
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
      subtitle: datePhrase(itinerary),
      leading: Hero(tag: tripHeroTag(itinerary.id), child: CoverImage(cover)),
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
        const Padding(padding: gutter, child: SectionHeading("Saved tours")),
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
            label: "Remove from saved",
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
        const _Title(),
        const SizedBox(height: AppSpace.section),
        Text("Plans need an account", style: AppTypography.titleMedium),
        const SizedBox(height: AppSpace.x2),
        Text(
          // Says what signing in buys, rather than simply refusing.
          // Browsing and downloading both work without one, so the reason
          // has to be specific or it reads as an arbitrary gate.
          "Itineraries are kept with your account so they follow you to "
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
            child: const Text("Sign in"),
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

/// The trip that comes next, the largest thing on the Itineraries tab: its
/// first stop's photo, NEXT UP on it, the name in the hero step and the
/// dates on the scrim, and under the photo the first stops in order, each a
/// photo with its number, so the plan reads as a route before it is opened.
///
/// The photo is the trip's `Hero`: it grows into the route map at the top of
/// the trip when the card is tapped.
class _NextTripCard extends ConsumerWidget {
  const _NextTripCard({required this.trip});

  final Itinerary trip;

  /// Stops shown under the photo; the rest are one tap away.
  static const _shown = 4;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final places = ref.watch(placesByIdProvider);
    final stops = [for (final id in trip.destinationIds) ?places[id]];
    final dates = datePhrase(trip);
    void open() => context.push(Routes.itinerary(trip.id));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Pressable(
          child: ClipRRect(
            borderRadius: AppRadii.lgAll,
            child: AspectRatio(
              aspectRatio: 16 / 11,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Hero(
                    tag: tripHeroTag(trip.id),
                    child: CoverImage(stops.firstOrNull?.coverImage),
                  ),
                  Material(
                    type: MaterialType.transparency,
                    child: InkWell(onTap: open),
                  ),
                  const Positioned(
                    top: AppSpace.x4,
                    left: AppSpace.x4,
                    child: LakbayanBadge("Next up", kind: BadgeKind.info),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: IgnorePointer(
                      child: MediaScrim(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              trip.name,
                              style: AppTypography.hero.copyWith(
                                color: Colors.white,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            // The dates or nothing: a stop count under a
                            // name is a dangling number (itinerary_copy).
                            if (dates != null)
                              Text(
                                dates,
                                style: AppTypography.labelMedium.copyWith(
                                  color: Colors.white,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (stops.isNotEmpty) ...[
          const SizedBox(height: AppSpace.x3),
          _StopsInOrder(stops: stops.take(_shown).toList()),
        ],
      ],
    );
  }
}

/// The first stops, left to right in visiting order, a number on each.
class _StopsInOrder extends StatelessWidget {
  const _StopsInOrder({required this.stops});

  final List<Destination> stops;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      for (final (index, place) in stops.indexed) ...[
        if (index > 0) const SizedBox(width: AppSpace.x2),
        Expanded(
          child: Semantics(
            label: "Stop ${index + 1}, ${place.name}",
            excludeSemantics: true,
            child: AspectRatio(
              aspectRatio: 1,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: AppRadii.smAll,
                    child: CoverImage(place.coverImage),
                  ),
                  Positioned(
                    left: AppSpace.x1,
                    top: AppSpace.x1,
                    child: StopNumeral(index + 1),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
      // Fewer than four keeps each photo its size rather than stretching.
      for (var i = stops.length; i < _NextTripCard._shown; i++) ...[
        const SizedBox(width: AppSpace.x2),
        const Expanded(child: SizedBox.shrink()),
      ],
    ],
  );
}
