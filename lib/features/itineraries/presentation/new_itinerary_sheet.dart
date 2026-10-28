import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";

import "../../../core/models/destination.dart";
import "../../../core/router/app_router.dart";
import "../../../core/theme/app_dimens.dart";
import "../../../core/theme/app_icons.dart";
import "../../../core/theme/app_typography.dart";
import "../../../core/widgets/chrome/app_sheet.dart";
import "../../../core/widgets/content/quiet_note.dart";
import "../domain/itinerary_actions.dart";
import "../domain/itinerary_providers.dart";
import "trip_dates.dart";
import "stop_picker.dart";

/// The new-itinerary sheet (redesign 2d). An interrupting task, so it gets
/// the scrim; at most 62% of the screen, rising from the bottom; dismissed by
/// drag, a scrim tap or system back.
///
/// It collects, in order: a name, start and end dates side by side (each
/// opening a calendar in place), and a first stop: a search field over the
/// places, the saved ones first under Saved, then the rest. One full-width
/// Create, pinned. Lands on the overview.
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
  final _search = TextEditingController();
  DateTime? _start;
  DateTime? _end;
  Destination? _firstStop;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _search.dispose();
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
    final query = _search.text;
    final (:saved, :rest) = ref.watch(firstStopChoicesProvider(query));
    final searching = query.trim().isNotEmpty;
    final anyPlaces = ref.watch(
      firstStopChoicesProvider("")
          .select((all) => all.saved.isNotEmpty || all.rest.isNotEmpty),
    );
    final canCreate = _name.text.trim().isNotEmpty && !_saving;
    const inset = EdgeInsets.symmetric(horizontal: AppSpace.gutter);
    final chosen = {?_firstStop?.id};
    void toggle(Destination place) => setState(() {
      _firstStop = _firstStop?.id == place.id ? null : place;
    });

    return AppSheet(
      title: "New Trip",
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
        if (anyPlaces) ...[
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.gutter,
              AppSpace.x3,
              AppSpace.gutter,
              AppSpace.x2,
            ),
            sliver: SliverList.list(
              children: [
                Text("First Stop", style: AppTypography.groupHeading),
                const SizedBox(height: AppSpace.x2),
                // The field's label is its placeholder; the lens is the
                // field's own conventional mark, as on any search.
                TextField(
                  controller: _search,
                  textInputAction: TextInputAction.search,
                  style: AppTypography.bodyLarge.copyWith(
                    color: scheme.onSurface,
                  ),
                  decoration: const InputDecoration(
                    hintText: "Search Places",
                    prefixIcon: Icon(AppIcons.search, size: AppSize.glyph),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ],
            ),
          ),
          if (saved.isNotEmpty) ...[
            const _Group("Saved"),
            SliverPadding(
              padding: inset,
              sliver: SliverStopPicker(
                items: saved,
                selected: chosen,
                onToggle: toggle,
              ),
            ),
          ],
          if (rest.isNotEmpty) ...[
            // A heading only when there are two groups to tell apart.
            if (saved.isNotEmpty) const _Group("More Places"),
            SliverPadding(
              padding: inset,
              sliver: SliverStopPicker(
                items: rest,
                selected: chosen,
                onToggle: toggle,
              ),
            ),
          ],
          if (searching && saved.isEmpty && rest.isEmpty)
            const SliverPadding(
              padding: inset,
              sliver: SliverToBoxAdapter(
                child: QuietNote("No places match that."),
              ),
            ),
        ],
      ],
    );
  }
}

/// A small heading over one group of the first stop's places.
class _Group extends StatelessWidget {
  const _Group(this.title);

  final String title;

  @override
  Widget build(BuildContext context) => SliverPadding(
    padding: const EdgeInsets.fromLTRB(
      AppSpace.gutter,
      AppSpace.x3,
      AppSpace.gutter,
      AppSpace.x2,
    ),
    sliver: SliverToBoxAdapter(
      child: Text(title, style: AppTypography.groupHeading),
    ),
  );
}
