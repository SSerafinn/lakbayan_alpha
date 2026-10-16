import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";

import "../../../core/models/destination.dart";
import "../../../core/router/app_router.dart";
import "../../../core/theme/app_dimens.dart";
import "../../../core/theme/app_typography.dart";
import "../../../core/widgets/chrome/app_sheet.dart";
import "../domain/itinerary_actions.dart";
import "../domain/itinerary_providers.dart";
import "trip_dates.dart";
import "stop_picker.dart";

/// The new-itinerary sheet (redesign 2d). An interrupting task, so it gets
/// the scrim; at most 62% of the screen, rising from the bottom; dismissed by
/// drag, the close symbol, a scrim tap or system back.
///
/// It collects, in order: a name, start and end dates side by side (each
/// opening a calendar in place), and a first stop. One full-width Create,
/// pinned. Lands on the overview.
///
/// The name field takes focus at once, so the keyboard is up from the first
/// frame; [AppSheet] sits the sheet on top of it and scrolls the body, which
/// is what keeps this sheet from overflowing on a short phone.
Future<void> showNewItinerary(BuildContext context) =>
    showAppSheet<void>(context, builder: (_) => const _NewItinerarySheet());

class _NewItinerarySheet extends ConsumerStatefulWidget {
  const _NewItinerarySheet();

  @override
  ConsumerState<_NewItinerarySheet> createState() => _NewItinerarySheetState();
}

class _NewItinerarySheetState extends ConsumerState<_NewItinerarySheet> {
  final _name = TextEditingController();
  DateTime? _start;
  DateTime? _end;
  Destination? _firstStop;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    setState(() => _saving = true);
    final router = GoRouter.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final id = await ref
        .read(itineraryActionsProvider)
        .create(
          name: name,
          stops: [?_firstStop?.id],
          startDate: _start,
          endDate: _end,
        );
    if (!mounted) return;
    if (id == null) {
      setState(() => _saving = false);
      messenger.showSnackBar(
        const SnackBar(content: Text("Couldn't create it. Try again.")),
      );
      return;
    }
    Navigator.of(context).pop();
    router.push(Routes.itinerary(id));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Hidden while loading, when empty and on an error alike: the first stop
    // is optional, and a trip is made from a name alone.
    final choices = ref.watch(firstStopChoicesProvider);
    final canCreate = _name.text.trim().isNotEmpty && !_saving;
    const inset = EdgeInsets.symmetric(horizontal: AppSpace.gutter);

    return AppSheet(
      title: "New itinerary",
      fill: true,
      action: FilledButton(
        onPressed: canCreate ? _create : null,
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(AppSize.primaryButton),
        ),
        child: const Text("Create"),
      ),
      slivers: [
        SliverPadding(
          padding: appSheetBodyPadding,
          sliver: SliverList.list(
            children: [
              TextField(
                controller: _name,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                style: AppTypography.bodyLarge.copyWith(
                  color: scheme.onSurface,
                ),
                decoration: const InputDecoration(hintText: "Name"),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: AppSpace.x3),
              TripDates(
                start: _start,
                end: _end,
                onChanged: (start, end) => setState(() {
                  _start = start;
                  _end = end;
                }),
              ),
            ],
          ),
        ),
        if (choices.isNotEmpty) ...[
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.gutter,
              AppSpace.x3,
              AppSpace.gutter,
              AppSpace.x2,
            ),
            sliver: SliverToBoxAdapter(
              child: Text("First stop", style: AppTypography.groupHeading),
            ),
          ),
          SliverPadding(
            padding: inset,
            sliver: SliverStopPicker(
              items: choices,
              selected: {?_firstStop?.id},
              onToggle: (place) => setState(() {
                _firstStop = _firstStop?.id == place.id ? null : place;
              }),
            ),
          ),
        ],
      ],
    );
  }
}
