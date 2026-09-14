import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";

import "../../../core/models/destination.dart";
import "../../../core/router/app_router.dart";
import "../../../core/theme/app_dimens.dart";
import "../../../core/theme/app_icons.dart";
import "../../../core/theme/app_typography.dart";
import "../../../core/widgets/symbol_button.dart";
import "../../auth/domain/auth_providers.dart";
import "../../destinations/domain/destination_providers.dart";
import "../domain/itinerary_copy.dart";
import "../domain/itinerary_providers.dart";
import "stop_picker.dart";

/// The new-itinerary sheet (redesign 2d). An interrupting task, so it gets
/// the scrim; about 62% of the screen, rising from the bottom; dismissed by
/// drag, the close symbol, a scrim tap or system back.
///
/// It collects, in order: a name, start and end dates side by side, and a
/// first stop. One full-width Create at the bottom. Lands on the overview.
Future<void> showNewItinerary(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: false,
      builder: (context) => const _NewItinerarySheet(),
    );

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

  static const _heightFactor = 0.62;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _pickStart() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _start ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 3),
    );
    if (picked == null) return;
    setState(() {
      _start = picked;
      if (_end != null && _end!.isBefore(picked)) _end = picked;
    });
  }

  Future<void> _pickEnd() async {
    final now = DateTime.now();
    final floor = _start ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: _end != null && !_end!.isBefore(floor) ? _end! : floor,
      // The picker enforces end on or after start; no error line needed.
      firstDate: floor,
      lastDate: DateTime(now.year + 3),
    );
    if (picked == null) return;
    setState(() => _end = picked);
  }

  Future<void> _create() async {
    final name = _name.text.trim();
    final uid = ref.read(authStateProvider).value?.uid;
    if (name.isEmpty || uid == null) return;
    setState(() => _saving = true);
    try {
      final id = await ref
          .read(itineraryRepositoryProvider)
          .create(
            uid,
            name: name,
            destinationIds: [?_firstStop?.id],
            startDate: _start,
            endDate: _end,
          );
      if (!mounted) return;
      Navigator.of(context).pop();
      context.push(Routes.itinerary(id));
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Couldn't create it. $error")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final places = ref.watch(allDestinationsProvider).value ?? const [];
    final choices = places.take(8).toList();
    final canCreate = _name.text.trim().isNotEmpty && !_saving;

    return FractionallySizedBox(
      heightFactor: _heightFactor,
      child: Padding(
        padding: EdgeInsets.only(bottom: keyboard),
        child: Column(
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
                      "New itinerary",
                      style: AppTypography.titleMedium,
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
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpace.gutter,
                  AppSpace.x3,
                  AppSpace.gutter,
                  AppSpace.x3,
                ),
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
                  Row(
                    children: [
                      Expanded(
                        child: _DateField(
                          label: "Start date",
                          value: _start,
                          onTap: _pickStart,
                        ),
                      ),
                      const SizedBox(width: AppSpace.x3),
                      Expanded(
                        child: _DateField(
                          label: "End date",
                          value: _end,
                          onTap: _pickEnd,
                        ),
                      ),
                    ],
                  ),
                  if (choices.isNotEmpty) ...[
                    const SizedBox(height: AppSpace.section),
                    Text("First stop", style: AppTypography.groupHeading),
                    const SizedBox(height: AppSpace.x2),
                    StopPicker(
                      items: choices,
                      selected: {?_firstStop?.id},
                      onToggle: (place) => setState(() {
                        _firstStop = _firstStop?.id == place.id ? null : place;
                      }),
                    ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpace.gutter,
                AppSpace.x2,
                AppSpace.gutter,
                AppSpace.gutter,
              ),
              child: FilledButton(
                onPressed: canCreate ? _create : null,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(AppSize.primaryButton),
                ),
                child: const Text("Create"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A read-only field that opens the date picker. The label is the
/// placeholder; the value replaces it.
class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final DateTime? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final date = value;
    return Semantics(
      button: true,
      label: date == null ? label : "$label, ${shortDate(date)}",
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadii.smAll,
        child: InputDecorator(
          decoration: InputDecoration(
            hintText: label,
            suffixIcon: const Icon(AppIcons.calendar, size: 20),
          ),
          isEmpty: date == null,
          child: date == null
              ? null
              : Text(
                  shortDate(date),
                  style: AppTypography.bodyLarge.copyWith(
                    color: scheme.onSurface,
                  ),
                ),
        ),
      ),
    );
  }
}
