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
import "../../../core/widgets/motion/motion.dart";
import "../../auth/domain/auth_providers.dart";
import "../domain/itinerary_actions.dart";
import "../domain/itinerary_copy.dart";
import "../domain/itinerary_providers.dart";
import "stop_picker.dart";

/// Put a destination into one of the user's itineraries.
///
/// **One job:** put this place on a trip and see it land there. **Emotion:**
/// momentum, a plan taking shape.
///
/// A modal sheet, not a screen: it is one choice from a short list, and
/// pushing a route would lose the destination behind it. Interrupting, so it
/// carries the scrim; the close symbol is the cancel.
///
/// Picking a trip turns the same sheet into its confirmation: a check pops
/// in, the title says where the place went, and **View trip** opens the
/// itinerary with the new stop landing in it. "New itinerary with this stop"
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

/// Marks the "new itinerary" row as the one that failed.
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
  bool _busy = false;

  Future<void> _add(Itinerary itinerary) async {
    setState(() => _busy = true);
    final landed = await ref
        .read(itineraryActionsProvider)
        .addStop(itinerary, widget.destinationId);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _addedTo = landed ? itinerary : null;
      _failed = landed ? null : itinerary.id;
    });
  }

  Future<void> _createAndOpen() async {
    setState(() => _busy = true);
    final router = GoRouter.of(context);
    final id = await ref
        .read(itineraryActionsProvider)
        .create(name: widget.destinationName, stops: [widget.destinationId]);
    if (!mounted) return;
    if (id == null) {
      setState(() {
        _busy = false;
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
        title: "Added to ${addedTo.name}",
        action: FilledButton(
          onPressed: () =>
              _open(Routes.itinerary(addedTo.id, added: widget.destinationId)),
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(AppSize.primaryButton),
          ),
          child: const Text("View trip"),
        ),
        slivers: [
          SliverPadding(
            padding: appSheetBodyPadding,
            sliver: SliverToBoxAdapter(
              child: _Confirmation(place: widget.destinationName),
            ),
          ),
        ],
      );
    }

    return AppSheet(
      title: "Add ${widget.destinationName} to",
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
              child: const Text("Sign in"),
            )
          : null,
      slivers: [
        SliverPadding(
          padding: appSheetBodyPadding,
          sliver: uid == null
              ? const SliverToBoxAdapter(child: _GuestNote())
              : _Trips(
                  destinationId: widget.destinationId,
                  failed: _failed,
                  busy: _busy,
                  onAdd: _add,
                  onCreate: _createAndOpen,
                ),
        ),
      ],
    );
  }
}

/// The user's trips, then "New itinerary with this stop".
class _Trips extends ConsumerWidget {
  const _Trips({
    required this.destinationId,
    required this.failed,
    required this.busy,
    required this.onAdd,
    required this.onCreate,
  });

  final String destinationId;
  final String? failed;
  final bool busy;
  final ValueChanged<Itinerary> onAdd;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return ref
        .watch(myItinerariesProvider)
        .whenLocalFirst(
          loading: () => const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(AppSpace.x6),
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
          error: (error, _) => SliverToBoxAdapter(
            child: QuietNote(
              errorCopy("Couldn't load your itineraries.", error),
              onRetry: () => ref.invalidate(myItinerariesProvider),
            ),
          ),
          data: (items) => SliverGroupedSection(
            itemCount: items.length + 1,
            itemBuilder: (context, index) {
              if (index == items.length) {
                return GroupedRow(
                  title: "New itinerary with this stop",
                  leadingGlyph: AppIcons.add,
                  glyphColor: scheme.primary,
                  trailing: failed == _newTrip
                      ? const _Failed()
                      : GroupedRow.noAccessory,
                  onTap: busy ? null : onCreate,
                );
              }
              final itinerary = items[index];
              final already = itinerary.destinationIds.contains(destinationId);
              return GroupedRow(
                title: itinerary.name,
                // Not an error, and not a reason to hide the row: seeing it
                // listed and marked is how somebody confirms they already
                // added it.
                subtitle: already
                    ? "Already on this trip"
                    : datePhrase(itinerary),
                trailing: failed == itinerary.id
                    ? const _Failed()
                    : SelectionCircle(selected: already),
                onTap: already || busy ? null : () => onAdd(itinerary),
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

/// The place, now on the trip: a check that pops in as the sheet changes
/// shape, then the place's name.
class _Confirmation extends StatelessWidget {
  const _Confirmation({required this.place});

  final String place;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        PopIn(
          child: SizedBox.square(
            dimension: AppSize.rowGlyphCircle,
            child: DecoratedBox(
              decoration: ShapeDecoration(
                color: scheme.primary,
                shape: const CircleBorder(),
              ),
              child: Icon(
                AppIcons.check,
                size: AppSize.glyphLg,
                color: scheme.onPrimary,
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpace.x3),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                place,
                style: AppTypography.titleSmall,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                "The last stop, for now",
                style: AppTypography.secondLine.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _GuestNote extends StatelessWidget {
  const _GuestNote();

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text("Plans need an account", style: AppTypography.titleSmall),
      const SizedBox(height: AppSpace.x2),
      Text(
        "Itineraries are kept with your account so they follow you to "
        "another phone.",
        style: AppTypography.bodyMedium.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    ],
  );
}
