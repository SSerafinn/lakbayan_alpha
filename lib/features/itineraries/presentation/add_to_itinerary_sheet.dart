import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";

import "../../../core/errors/error_copy.dart";
import "../../../core/errors/local_first.dart";
import "../../../core/models/itinerary.dart";
import "../../../core/router/app_router.dart";
import "../../../core/theme/app_dimens.dart";
import "../../../core/theme/app_icons.dart";
import "../../../core/theme/app_typography.dart";
import "../../../core/widgets/chrome/app_sheet.dart";
import "../../../core/widgets/content/grouped_section.dart";
import "../../../core/widgets/content/quiet_note.dart";
import "../../../core/widgets/content/storage_image.dart";
import "../../../core/widgets/motion/motion.dart";
import "../../auth/domain/auth_providers.dart";
import "../../destinations/domain/destination_providers.dart";
import "../domain/itinerary_actions.dart";
import "../domain/itinerary_copy.dart";
import "../domain/itinerary_providers.dart";

/// Put a destination into one of the user's itineraries.
///
/// **One job:** put this place on a trip and see it land there. **Emotion:**
/// momentum, a plan taking shape.
///
/// A modal sheet, not a screen: it is one choice from a short list, and
/// pushing a route would lose the destination behind it. Interrupting, so it
/// carries the scrim; drag down, tap outside or use system back to cancel.
///
/// Picking a trip turns the same sheet into its confirmation: a check pops
/// in, the preview says where the place went, and **View Trip** opens the
/// itinerary with the new stop landing in it. **New Trip**
/// creates the trip and opens it straight away. A write that fails marks its
/// row with the warning glyph and stays tappable to try again.
Future<void> showAddToItinerary(
  BuildContext context, {
  required String destinationId,
  required String destinationName,
}) => showAppSheet<void>(
  context,
  builder: (_) => _AddToItinerarySheet(
    destinationId: destinationId,
    destinationName: destinationName,
  ),
);

/// Identifies the new-trip action while pending or failed.
const _newTrip = "";

class _AddToItinerarySheet extends ConsumerStatefulWidget {
  const _AddToItinerarySheet({
    required this.destinationId,
    required this.destinationName,
  });

  final String destinationId;
  final String destinationName;

  @override
  ConsumerState<_AddToItinerarySheet> createState() =>
      _AddToItinerarySheetState();
}

class _AddToItinerarySheetState extends ConsumerState<_AddToItinerarySheet> {
  Itinerary? _addedTo;
  String? _failed;
  String? _pending;

  bool get _busy => _pending != null;

  Future<void> _add(Itinerary itinerary) async {
    if (_busy || itinerary.destinationIds.contains(widget.destinationId)) {
      return;
    }
    setState(() {
      _pending = itinerary.id;
      _failed = null;
    });
    final landed = await ref
        .read(itineraryActionsProvider)
        .addStop(itinerary, widget.destinationId);
    if (!mounted) return;
    setState(() {
      _pending = null;
      _addedTo = landed ? itinerary : null;
      _failed = landed ? null : itinerary.id;
    });
  }

  Future<void> _createAndOpen() async {
    if (_busy) return;
    setState(() {
      _pending = _newTrip;
      _failed = null;
    });
    final router = GoRouter.of(context);
    final id = await ref
        .read(itineraryActionsProvider)
        .create(name: widget.destinationName, stops: [widget.destinationId]);
    if (!mounted) return;
    if (id == null) {
      setState(() {
        _pending = null;
        _failed = _newTrip;
      });
      return;
    }
    Navigator.of(context).pop();
    router.push(Routes.itinerary(id, added: widget.destinationId));
  }

  void _open(String route) {
    final router = GoRouter.of(context);
    Navigator.of(context).pop();
    router.push(route);
  }

  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(authStateProvider.select((auth) => auth.value?.uid));
    final addedTo = _addedTo;

    if (addedTo != null) {
      return AppSheet(
        title: "Added to Trip",
        action: FilledButton(
          onPressed: () =>
              _open(Routes.itinerary(addedTo.id, added: widget.destinationId)),
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(AppSize.primaryButton),
          ),
          child: const Text("View Trip"),
        ),
        slivers: [
          SliverPadding(
            padding: appSheetBodyPadding,
            sliver: SliverToBoxAdapter(
              child: _PlacePreview(
                id: widget.destinationId,
                name: widget.destinationName,
                addedTo: addedTo.name,
              ),
            ),
          ),
        ],
      );
    }

    return AppSheet(
      title: "Add to Trip",
      action: uid == null
          ? FilledButton(
              // Leaving guest mode is what sends the router to sign-in.
              onPressed: () {
                Navigator.of(context).pop();
                ref.read(guestModeProvider.notifier).disable();
              },
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(AppSize.primaryButton),
              ),
              child: const Text("Sign In"),
            )
          : Tooltip(
              message: _failed == _newTrip
                  ? "Couldn't create the trip. Try again."
                  : "Create a trip with this place",
              child: OutlinedButton(
                onPressed: _busy ? null : _createAndOpen,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(AppSize.primaryButton),
                ),
                child: _pending == _newTrip
                    ? const _Pending()
                    : Text(_failed == _newTrip ? "Try Again" : "New Trip"),
              ),
            ),
      slivers: [
        SliverPadding(
          padding: appSheetBodyPadding,
          sliver: SliverToBoxAdapter(
            child: _PlacePreview(
              id: widget.destinationId,
              name: widget.destinationName,
            ),
          ),
        ),
        SliverPadding(
          padding: appSheetBodyPadding,
          sliver: uid == null
              ? const SliverToBoxAdapter(child: _GuestNote())
              : _Trips(
                  destinationId: widget.destinationId,
                  failed: _failed,
                  pending: _pending,
                  onAdd: _add,
                ),
        ),
      ],
    );
  }
}

/// Eligible trips keep the source's cached results and retry behavior.
class _Trips extends ConsumerWidget {
  const _Trips({
    required this.destinationId,
    required this.failed,
    required this.pending,
    required this.onAdd,
  });

  final String destinationId;
  final String? failed;
  final String? pending;
  final ValueChanged<Itinerary> onAdd;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(tripsAcceptingStopProvider(destinationId))
        .whenLocalFirst(
          loading: () => const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(AppSpace.x6),
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
          error: (error, _) => SliverToBoxAdapter(
            child: QuietNote(
              errorCopy("Couldn't load your trips.", error),
              onRetry: () => ref.invalidate(myItinerariesProvider),
            ),
          ),
          data: (items) => items.isEmpty
              ? const SliverToBoxAdapter(
                  child: QuietNote("No trips to choose from."),
                )
              : SliverGroupedSection(
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final itinerary = items[index];
                    return GroupedRow(
                      title: itinerary.name,
                      subtitle:
                          datePhrase(itinerary) ??
                          stopsPhrase(itinerary.destinationIds.length),
                      trailing: pending == itinerary.id
                          ? const _Pending()
                          : failed == itinerary.id
                          ? const _Failed()
                          : null,
                      onTap: pending != null ? null : () => onAdd(itinerary),
                    );
                  },
                ),
        );
  }
}

/// The write did not land: the warning glyph, its reason in the tooltip.
/// The row stays tappable, so tapping again is the retry.
class _Failed extends StatelessWidget {
  const _Failed();

  @override
  Widget build(BuildContext context) => Tooltip(
    message: "Couldn't add it. Tap to try again.",
    child: Icon(
      AppIcons.warning,
      size: AppSize.glyphLg,
      color: Theme.of(context).colorScheme.error,
    ),
  );
}

class _PlacePreview extends ConsumerWidget {
  const _PlacePreview({required this.id, required this.name, this.addedTo});

  final String id;
  final String name;
  final String? addedTo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final place = ref.watch(destinationByIdProvider(id)).value;
    return GroupedSection(
      children: [
        GroupedRow(
          title: name,
          subtitle: addedTo ?? place?.town,
          leading: CoverImage(place?.coverImage),
          trailing: addedTo == null
              ? GroupedRow.noAccessory
              : PopIn(
                  child: Icon(
                    AppIcons.check,
                    size: AppSize.glyphLg,
                    color: Theme.of(context).colorScheme.primary,
                    semanticLabel: "Added",
                  ),
                ),
        ),
      ],
    );
  }
}

class _Pending extends StatelessWidget {
  const _Pending();

  @override
  Widget build(BuildContext context) => const SizedBox.square(
    dimension: AppSize.glyphLg,
    child: CircularProgressIndicator(semanticsLabel: "Adding to trip"),
  );
}

class _GuestNote extends StatelessWidget {
  const _GuestNote();

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text("Plans Need an Account", style: AppTypography.titleSmall),
      const SizedBox(height: AppSpace.x2),
      Text(
        "Trips are kept with your account so they follow you to "
        "another phone.",
        style: AppTypography.bodyMedium.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    ],
  );
}
