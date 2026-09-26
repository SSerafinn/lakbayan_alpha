import "package:flutter/material.dart";

import "../../../core/theme/app_dimens.dart";
import "../../../core/theme/app_icons.dart";
import "../../../core/theme/app_typography.dart";
import "../../../core/widgets/controls/month_calendar.dart";
import "../../../core/widgets/motion/motion.dart";
import "../domain/itinerary_copy.dart";

enum _Slot { start, end }

/// A trip's start and end dates, side by side, each opening a calendar in
/// place under the pair (the new-itinerary sheet and Change dates).
///
/// Tapping a field grows the calendar out from under it on
/// `AppMotion.chrome`; the open field takes the focus border, so it is clear
/// which date the calendar sets. Picking a start moves straight on to the
/// end, which cannot fall before it; picking the end folds the calendar
/// away. Tapping the open field again closes it.
class TripDates extends StatefulWidget {
  const TripDates({
    required this.start,
    required this.end,
    required this.onChanged,
    super.key,
  });

  final DateTime? start;
  final DateTime? end;
  final void Function(DateTime? start, DateTime? end) onChanged;

  @override
  State<TripDates> createState() => _TripDatesState();
}

class _TripDatesState extends State<TripDates> {
  _Slot? _open;

  /// The last slot opened, so the calendar keeps its content while it folds.
  _Slot _shown = _Slot.start;

  late final DateTime _first = DateUtils.dateOnly(DateTime.now())
      .subtract(const Duration(days: 365));
  late final DateTime _last = DateTime(DateTime.now().year + 3, 12, 31);

  void _toggle(_Slot slot) => setState(() {
    _open = _open == slot ? null : slot;
    if (_open != null) _shown = slot;
  });

  void _pick(DateTime date) {
    final start = widget.start;
    final end = widget.end;
    if (_shown == _Slot.start) {
      widget.onChanged(date, end != null && end.isBefore(date) ? date : end);
      setState(() => _open = _shown = _Slot.end);
    } else {
      widget.onChanged(start, date);
      setState(() => _open = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final start = widget.start;
    final floor = _shown == _Slot.end && start != null ? start : _first;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: _DateField(
                label: "Start date",
                value: start,
                open: _open == _Slot.start,
                onTap: () => _toggle(_Slot.start),
              ),
            ),
            const SizedBox(width: AppSpace.x3),
            Expanded(
              child: _DateField(
                label: "End date",
                value: widget.end,
                open: _open == _Slot.end,
                onTap: () => _toggle(_Slot.end),
              ),
            ),
          ],
        ),
        Fold(
          open: _open != null,
          // Keyed by slot so the calendar opens on that slot's month.
          child: Padding(
            padding: const EdgeInsets.only(top: AppSpace.x3),
            child: MonthCalendar(
              key: ValueKey(_shown),
              selected: _shown == _Slot.start ? start : widget.end,
              firstDate: floor,
              lastDate: _last,
              onSelected: _pick,
            ),
          ),
        ),
      ],
    );
  }
}

/// A read-only field that opens the calendar. The label is the placeholder;
/// the value replaces it with a cross-fade.
class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.open,
    required this.onTap,
  });

  final String label;
  final DateTime? value;
  final bool open;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final date = value;
    return Semantics(
      button: true,
      expanded: open,
      label: date == null ? label : "$label, ${shortDate(date)}",
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadii.smAll,
        child: InputDecorator(
          isFocused: open,
          isEmpty: date == null,
          decoration: InputDecoration(
            hintText: label,
            suffixIcon: const Icon(AppIcons.calendar, size: AppSize.glyph),
          ),
          child: FadeSwap(
            id: date,
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              date == null ? "" : shortDate(date),
              style: AppTypography.bodyLarge.copyWith(color: scheme.onSurface),
            ),
          ),
        ),
      ),
    );
  }
}
