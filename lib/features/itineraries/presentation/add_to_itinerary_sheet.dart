import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../../core/models/itinerary.dart";
import "../../../core/theme/app_dimens.dart";
import "../../../core/theme/app_icons.dart";
import "../../../core/theme/app_typography.dart";
import "../../../core/widgets/grouped_section.dart";
import "../../../core/widgets/symbol_button.dart";
import "../../auth/domain/auth_providers.dart";
import "../domain/itinerary_copy.dart";
import "../domain/itinerary_providers.dart";
import "stop_picker.dart";

/// Put a destination into one of the user's itineraries.
///
/// A modal sheet, not a screen: it is one choice from a short list, and
/// pushing a route would lose the destination behind it. Interrupting, so it
/// carries the scrim; the close symbol is the cancel.
Future<void> showAddToItinerary(
  BuildContext context, {
  required String destinationId,
  required String destinationName,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: false,
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
    final scheme = Theme.of(context).colorScheme;
    final uid = ref.watch(authStateProvider).value?.uid;
    final itineraries = ref.watch(myItinerariesProvider);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSpace.x2),
        Center(
          child: Container(
            width: AppSize.dragHandleWidth,
            height: AppSize.dragHandleHeight,
            decoration: ShapeDecoration(
              color: scheme.outlineVariant,
              shape: const StadiumBorder(),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.gutter,
            AppSpace.x2,
            AppSpace.x2,
            0,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  "Add $destinationName to",
                  style: AppTypography.titleMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              SymbolButton(
                icon: AppIcons.close,
                tooltip: "Close",
                onTap: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
        Flexible(
          child: uid == null
              ? const _GuestNote()
              : itineraries.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.all(AppSpace.x6),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (e, _) => Padding(
                    padding: const EdgeInsets.all(AppSpace.gutter),
                    child: Text(
                      "Couldn't load your itineraries.\n$e",
                      style: AppTypography.bodyMedium.copyWith(
                        color: scheme.error,
                      ),
                    ),
                  ),
                  // shrinkWrap so the sheet hugs a handful of rows; the
                  // list is one person's own trips, never long.
                  data: (items) => ListView(
                    shrinkWrap: true,
                    padding: const EdgeInsets.fromLTRB(
                      AppSpace.gutter,
                      AppSpace.x3,
                      AppSpace.gutter,
                      AppSpace.gutter,
                    ),
                    children: [
                      GroupedSection(
                        children: [
                          for (final itinerary in items)
                            _Row(
                              itinerary: itinerary,
                              destinationId: destinationId,
                              uid: uid,
                            ),
                          GroupedRow(
                            title: "New itinerary with this stop",
                            leadingGlyph: AppIcons.add,
                            glyphColor: scheme.primary,
                            trailing: GroupedRow.noAccessory,
                            onTap: () => _createAndAdd(context, ref, uid),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
        ),
      ],
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

    return GroupedRow(
      title: itinerary.name,
      // Not an error, and not a reason to hide the row: seeing it listed and
      // marked is how somebody confirms they already added it.
      subtitle: already ? "Already on this trip" : itineraryLine(itinerary),
      trailing: SelectionCircle(selected: already),
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

class _GuestNote extends StatelessWidget {
  const _GuestNote();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      AppSpace.gutter,
      AppSpace.x3,
      AppSpace.gutter,
      AppSpace.section,
    ),
    child: Column(
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
    ),
  );
}
