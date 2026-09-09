import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../../core/models/itinerary.dart";
import "../../../core/theme/app_dimens.dart";
import "../../../core/theme/app_typography.dart";
import "../../../core/theme/lakbayan_colors.dart";
import "../../auth/domain/auth_providers.dart";
import "../domain/itinerary_providers.dart";

/// Put a destination into one of the user's itineraries.
///
/// A sheet rather than a screen: it is one choice from a short list, and
/// pushing a route would lose the destination behind it.
Future<void> showAddToItinerary(
  BuildContext context, {
  required String destinationId,
  required String destinationName,
}) => showModalBottomSheet<void>(
  context: context,
  showDragHandle: true,
  isScrollControlled: true,
  builder: (context) => _AddToItinerarySheet(
    destinationId: destinationId,
    destinationName: destinationName,
  ),
);

class _AddToItinerarySheet extends ConsumerWidget {
  const _AddToItinerarySheet({
    required this.destinationId,
    required this.destinationName,
  });

  final String destinationId;
  final String destinationName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.lakbayan;
    final uid = ref.watch(authStateProvider).value?.uid;
    final itineraries = ref.watch(myItinerariesProvider);

    if (uid == null) {
      return Padding(
        padding: const EdgeInsets.all(AppSpace.x6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Plans need an account", style: AppTypography.h3),
            const SizedBox(height: AppSpace.x2),
            Text(
              "Itineraries are kept with your account so they follow you to "
              "another phone.",
              style: AppTypography.body.copyWith(color: c.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpace.x4,
          0,
          AppSpace.x4,
          AppSpace.x4,
        ),
        child: itineraries.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(AppSpace.x6),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Padding(
            padding: const EdgeInsets.all(AppSpace.x4),
            child: Text(
              "Couldn't load your itineraries.\n$e",
              style: AppTypography.body.copyWith(color: c.badgeErrorText),
            ),
          ),
          data: (items) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text("Add $destinationName to…", style: AppTypography.h3),
              const SizedBox(height: AppSpace.x2),
              if (items.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpace.x3),
                  child: Text(
                    "You have no itineraries yet.",
                    style: AppTypography.body.copyWith(color: c.textSecondary),
                  ),
                )
              else
                for (final itinerary in items)
                  _Row(
                    itinerary: itinerary,
                    destinationId: destinationId,
                    uid: uid,
                  ),
              const SizedBox(height: AppSpace.x3),
              OutlinedButton.icon(
                onPressed: () => _createAndAdd(context, ref, uid),
                icon: const Icon(Icons.add),
                label: const Text("New itinerary with this stop"),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _createAndAdd(
    BuildContext context,
    WidgetRef ref,
    String uid,
  ) async {
    await ref
        .read(itineraryRepositoryProvider)
        .create(uid, name: destinationName, destinationIds: [destinationId]);
    if (context.mounted) Navigator.of(context).pop();
  }
}

class _Row extends ConsumerWidget {
  const _Row({
    required this.itinerary,
    required this.destinationId,
    required this.uid,
  });

  final Itinerary itinerary;
  final String destinationId;
  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final already = itinerary.destinationIds.contains(destinationId);

    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(itinerary.name, style: AppTypography.title),
      subtitle: Text(
        already
            // Not an error, and not a reason to hide the row: seeing it listed
            // and marked is how somebody confirms they already added it.
            ? "Already in this itinerary"
            : "${itinerary.destinationIds.length} stop"
                  "${itinerary.destinationIds.length == 1 ? "" : "s"}",
        style: AppTypography.caption,
      ),
      trailing: Icon(already ? Icons.check : Icons.add),
      enabled: !already,
      onTap: already
          ? null
          : () async {
              await ref.read(itineraryRepositoryProvider).setStops(
                uid,
                itinerary.id,
                [...itinerary.destinationIds, destinationId],
              );
              if (context.mounted) Navigator.of(context).pop();
            },
    );
  }
}
