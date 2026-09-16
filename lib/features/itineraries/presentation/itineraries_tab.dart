import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";

import "../../../core/models/itinerary.dart";
import "../../../core/router/app_router.dart";
import "../../../core/theme/app_dimens.dart";
import "../../../core/theme/app_icons.dart";
import "../../../core/theme/app_typography.dart";
import "../../../core/widgets/grouped_section.dart";
import "../../../core/widgets/quiet_note.dart";
import "../../../core/widgets/scroll_edge.dart";
import "../../auth/domain/auth_providers.dart";
import "../../destinations/domain/destination_providers.dart";
import "../../explore/domain/home_tab.dart";
import "../../maps/domain/map_route.dart";
import "../domain/itinerary_copy.dart";
import "../domain/itinerary_providers.dart";
import "new_itinerary_sheet.dart";

/// The Itineraries tab (redesign 2d).
///
/// **The screen's one job.** See my trips and start a new one.
///
/// **Emotion.** A plan taking form.
///
/// **Anatomy.** The title; one grouped section of the trips I built, the
/// second line carrying the dates when there are any; a "Saved tours"
/// heading and its own section for the province's tours I kept. The one
/// primary action, New itinerary, is the FAB.
///
/// Two lists that look alike and are not the same thing: **Saved** are the
/// province's tours somebody kept; **Mine** are tours they built. They live
/// in different collections because `tours` is admin-written.
class ItinerariesTab extends ConsumerWidget {
  const ItinerariesTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final signedIn = ref.watch(authStateProvider).value != null;
    final topInset = MediaQuery.viewPaddingOf(context).top;

    if (!signedIn) return const _GuestPrompt();

    return Stack(
      children: [
        ListView(
          padding: EdgeInsets.fromLTRB(
            AppSpace.gutter,
            topInset + AppSpace.x2,
            AppSpace.gutter,
            ScrollEdge.homeBarHeight(context) + AppSize.primaryButton * 2,
          ),
          children: const [
            _Title(),
            SizedBox(height: AppSpace.section),
            _Mine(),
            SizedBox(height: AppSpace.section),
            _SavedTours(),
          ],
        ),
        // Placed by hand rather than by a Scaffold so it clears the floating
        // tab bar exactly, gesture inset included.
        Positioned(
          right: AppSpace.gutter,
          bottom: ScrollEdge.homeBarHeight(context) + AppSpace.gutter,
          child: FloatingActionButton.extended(
            onPressed: () => showNewItinerary(context),
            icon: const Icon(AppIcons.add),
            label: const Text("New itinerary"),
          ),
        ),
      ],
    );
  }
}

class _Title extends StatelessWidget {
  const _Title();

  @override
  Widget build(BuildContext context) =>
      Text("Itineraries", style: AppTypography.titleLarge);
}

class _Mine extends ConsumerWidget {
  const _Mine();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mine = ref.watch(myItinerariesProvider);
    return mine.when(
      loading: () => const _Loading(),
      error: (e, _) => QuietNote("Couldn't load your itineraries.\n$e"),
      data: (items) => items.isEmpty
          ? const QuietNote(
              "Nothing planned yet. Make one, and add stops from any place.",
            )
          : GroupedSection(
              children: [
                for (final itinerary in items) _ItineraryRow(itinerary),
              ],
            ),
    );
  }
}

class _ItineraryRow extends StatelessWidget {
  const _ItineraryRow(this.itinerary);

  final Itinerary itinerary;

  @override
  Widget build(BuildContext context) => GroupedRow(
    title: itinerary.name,
    subtitle: itineraryLine(itinerary),
    onTap: () => context.push(Routes.itinerary(itinerary.id)),
  );
}

class _SavedTours extends ConsumerWidget {
  const _SavedTours();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saved = ref.watch(savedToursProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Saved tours", style: AppTypography.groupHeading),
        const SizedBox(height: AppSpace.x2),
        saved.when(
          loading: () => const _Loading(),
          error: (e, _) => QuietNote("Couldn't load your saved tours.\n$e"),
          data: (items) => items.isEmpty
              ? const QuietNote(
                  "Tours you save from the province's list appear here.",
                )
              : GroupedSection(
                  children: [for (final tour in items) _TourRow(tour: tour)],
                ),
        ),
      ],
    );
  }
}

class _TourRow extends ConsumerWidget {
  const _TourRow({required this.tour});

  final Tour tour;

  /// Draw the province's tour on the map — the same gesture an itinerary's
  /// "Open on the map" performs, and the only way to see one. A saved tour
  /// used to be a row you could do nothing with but delete, even though its
  /// stops are an ordered route.
  void _openOnMap(BuildContext context, WidgetRef ref) {
    ref.read(browseQueryProvider.notifier).update("");
    ref.read(browseCategoryProvider.notifier).select(null);
    ref.read(mapShowsSavedProvider.notifier).set(false);
    ref.read(browseShowsGridProvider.notifier).set(false);
    ref.read(mapSelectedIdProvider.notifier).select(null);
    ref.read(activeMapRouteProvider.notifier).show(tour.title, tour.stops);
    ref.read(selectedHomeTabProvider.notifier).select(HomeTab.map);
    context.go(Routes.home);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) => GroupedRow(
    title: tour.title,
    subtitle: tour.stops.isEmpty ? null : stopsPhrase(tour.stops.length),
    // A tour with no stops has no route to draw, so the row stays inert
    // rather than sending somebody to an empty map.
    onTap: tour.stops.isEmpty ? null : () => _openOnMap(context, ref),
    // A distinct action, so it is its own 48 target.
    trailing: IconButton(
      icon: const Icon(AppIcons.close, size: 18),
      tooltip: "Remove from saved",
      onPressed: () {
        final uid = ref.read(authStateProvider).value?.uid;
        if (uid == null) return;
        ref
            .read(userProfileRepositoryProvider)
            .setTourSaved(uid, tour.id, saved: false);
      },
    ),
  );
}

class _GuestPrompt extends ConsumerWidget {
  const _GuestPrompt();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final topInset = MediaQuery.viewPaddingOf(context).top;
    return ListView(
      padding: EdgeInsets.fromLTRB(
        AppSpace.gutter,
        topInset + AppSpace.x2,
        AppSpace.gutter,
        ScrollEdge.homeBarHeight(context),
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
        FilledButton(
          onPressed: () => ref.read(guestModeProvider.notifier).disable(),
          child: const Text("Sign in"),
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
