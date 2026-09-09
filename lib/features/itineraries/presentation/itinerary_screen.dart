import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";

import "../../../core/models/destination.dart";
import "../../../core/models/itinerary.dart";
import "../../../core/theme/app_dimens.dart";
import "../../../core/theme/app_typography.dart";
import "../../../core/theme/lakbayan_colors.dart";
import "../../auth/domain/auth_providers.dart";
import "../../destinations/domain/destination_providers.dart";
import "../domain/itinerary_providers.dart";

/// One itinerary: its stops, in order, and the ways to change that order.
///
/// Reordering is the point of the screen. The list order **is** the route, so
/// move-up and move-down are the primary controls rather than an afterthought —
/// and they are buttons, not a drag handle, for the reason the segments editor
/// gives: a handful of stops on a phone is easier to nudge than to drag, and
/// buttons are reachable with a screen reader.
class ItineraryScreen extends ConsumerWidget {
  const ItineraryScreen({required this.id, super.key});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itineraries = ref.watch(myItinerariesProvider);

    return itineraries.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: _Message("Couldn't load this itinerary.\n$e"),
      ),
      data: (items) {
        final itinerary = items.where((i) => i.id == id).firstOrNull;
        if (itinerary == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const _Message("This itinerary is no longer here."),
          );
        }
        return _Content(itinerary: itinerary);
      },
    );
  }
}

class _Content extends ConsumerWidget {
  const _Content({required this.itinerary});

  final Itinerary itinerary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(authStateProvider).value?.uid;
    final repository = ref.read(itineraryRepositoryProvider);
    final stops = itinerary.destinationIds;

    Future<void> reorder(int from, int to) async {
      if (uid == null) return;
      final next = [...stops];
      next.insert(to, next.removeAt(from));
      await repository.setStops(uid, itinerary.id, next);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(itinerary.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: "Delete this itinerary",
            onPressed: () => _confirmDelete(context, ref, itinerary),
          ),
        ],
      ),
      body: stops.isEmpty
          ? const _Message(
              "No stops yet.\n\n"
              "Open a destination and add it to this itinerary.",
            )
          : ListView.builder(
              padding: const EdgeInsets.all(AppSpace.x4),
              itemCount: stops.length,
              itemBuilder: (context, i) => _StopRow(
                index: i,
                total: stops.length,
                destinationId: stops[i],
                onUp: i == 0 ? null : () => reorder(i, i - 1),
                onDown: i == stops.length - 1 ? null : () => reorder(i, i + 1),
                onRemove: uid == null
                    ? null
                    : () => repository.setStops(
                        uid,
                        itinerary.id,
                        [...stops]..removeAt(i),
                      ),
              ),
            ),
    );
  }
}

Future<void> _confirmDelete(
  BuildContext context,
  WidgetRef ref,
  Itinerary itinerary,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text("Delete ${itinerary.name}?"),
      content: const Text("The stops go with it. This cannot be undone."),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text("Keep it"),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text("Delete"),
        ),
      ],
    ),
  );
  if (confirmed != true) return;

  final uid = ref.read(authStateProvider).value?.uid;
  if (uid == null) return;
  await ref.read(itineraryRepositoryProvider).delete(uid, itinerary.id);
  if (context.mounted) context.pop();
}

class _StopRow extends ConsumerWidget {
  const _StopRow({
    required this.index,
    required this.total,
    required this.destinationId,
    required this.onUp,
    required this.onDown,
    required this.onRemove,
  });

  final int index;
  final int total;
  final String destinationId;
  final VoidCallback? onUp;
  final VoidCallback? onDown;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.lakbayan;
    final destination = ref.watch(destinationByIdProvider(destinationId));

    return Semantics(
      label: "Stop ${index + 1} of $total",
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpace.x1),
        child: Row(
          children: [
            SizedBox(
              width: 28,
              child: Text("${index + 1}.", style: AppTypography.label),
            ),
            Expanded(
              child: destination.when(
                loading: () => const LinearProgressIndicator(),
                error: (_, _) => Text(
                  "This stop could not be loaded",
                  style: AppTypography.body.copyWith(color: c.badgeErrorText),
                ),
                data: (d) => d == null
                    // A destination can be unpublished after somebody added
                    // it. Saying so beats a blank row, and leaves them able to
                    // remove it.
                    ? Text(
                        "No longer available",
                        style: AppTypography.body.copyWith(
                          color: c.textSecondary,
                        ),
                      )
                    : _StopLabel(destination: d),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.arrow_upward),
              tooltip: "Move earlier",
              onPressed: onUp,
            ),
            IconButton(
              icon: const Icon(Icons.arrow_downward),
              tooltip: "Move later",
              onPressed: onDown,
            ),
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: "Remove this stop",
              onPressed: onRemove,
            ),
          ],
        ),
      ),
    );
  }
}

class _StopLabel extends StatelessWidget {
  const _StopLabel({required this.destination});

  final Destination destination;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        destination.name,
        style: AppTypography.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      Text(destination.town, style: AppTypography.caption),
    ],
  );
}

class _Message extends StatelessWidget {
  const _Message(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(AppSpace.x8),
      child: Text(text, style: AppTypography.body, textAlign: TextAlign.center),
    ),
  );
}
