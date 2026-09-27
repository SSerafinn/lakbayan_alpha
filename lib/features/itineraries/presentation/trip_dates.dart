import "package:animations/animations.dart";
import "package:flutter/material.dart";
import "package:motor/motor.dart";

import "../../../core/theme/app_dimens.dart";
import "../../../core/theme/app_icons.dart";
import "../../../core/theme/app_motion.dart";
import "../../../core/theme/app_typography.dart";
import "../../../core/theme/lakbayan_colors.dart";
import "../../../core/widgets/controls/bar_item_group.dart";
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
            child: _MonthCalendar(
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

/// One month of days, inline under the fields. The chosen day is a solid
/// green circle that glides between days on `AppMotion.chrome`; today is its
/// numeral in link green; days out of range are faint and inert. Months turn
/// along a horizontal shared axis, or cross-fade under reduced motion.
class _MonthCalendar extends StatefulWidget {
  const _MonthCalendar({
    required this.selected,
    required this.onSelected,
    required this.firstDate,
    required this.lastDate,
    super.key,
  });

  final DateTime? selected;
  final ValueChanged<DateTime> onSelected;
  final DateTime firstDate;
  final DateTime lastDate;

  @override
  State<_MonthCalendar> createState() => _MonthCalendarState();
}

/// Longer than a fade, shorter than a page; only this widget pages months.
const _monthTurn = Durations.medium2;

class _MonthCalendarState extends State<_MonthCalendar> {
  late DateTime _month;
  bool _forward = true;

  @override
  void initState() {
    super.initState();
    final anchor = widget.selected ?? _clamp(DateTime.now());
    _month = DateTime(anchor.year, anchor.month);
  }

  DateTime _clamp(DateTime date) {
    if (date.isBefore(widget.firstDate)) return widget.firstDate;
    if (date.isAfter(widget.lastDate)) return widget.lastDate;
    return date;
  }

  bool get _hasPrevious => DateTime(
    _month.year,
    _month.month,
  ).isAfter(DateTime(widget.firstDate.year, widget.firstDate.month));

  bool get _hasNext => DateTime(
    _month.year,
    _month.month,
  ).isBefore(DateTime(widget.lastDate.year, widget.lastDate.month));

  void _turn(int by) => setState(() {
    _forward = by > 0;
    _month = DateTime(_month.year, _month.month + by);
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final reduced = MediaQuery.disableAnimationsOf(context);
    final words = MaterialLocalizations.of(context);
    // The phone's own weekday initials; weeks run from Monday.
    final initials = words.narrowWeekdays;
    final weekdays = [for (var i = 1; i <= 7; i++) initials[i % 7]];

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                words.formatMonthYear(_month),
                style: AppTypography.groupHeading,
              ),
            ),
            BarItemGroup(
              items: [
                BarItem(
                  icon: AppIcons.back,
                  tooltip: "Previous month",
                  onPressed: _hasPrevious ? () => _turn(-1) : null,
                ),
                BarItem(
                  icon: AppIcons.chevron,
                  tooltip: "Next month",
                  onPressed: _hasNext ? () => _turn(1) : null,
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: AppSpace.x2),
        Row(
          children: [
            for (final initial in weekdays)
              Expanded(
                child: Text(
                  initial,
                  textAlign: TextAlign.center,
                  style: AppTypography.labelSmall.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpace.x1),
        PageTransitionSwitcher(
          duration: _monthTurn,
          reverse: !_forward,
          transitionBuilder: (child, animation, secondary) => reduced
              ? FadeTransition(opacity: animation, child: child)
              : SharedAxisTransition(
                  animation: animation,
                  secondaryAnimation: secondary,
                  transitionType: SharedAxisTransitionType.horizontal,
                  fillColor: scheme.surface,
                  child: child,
                ),
          child: _MonthGrid(
            key: ValueKey(_month),
            month: _month,
            selected: widget.selected,
            firstDate: DateUtils.dateOnly(widget.firstDate),
            lastDate: DateUtils.dateOnly(widget.lastDate),
            onSelected: widget.onSelected,
          ),
        ),
      ],
    );
  }
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.month,
    required this.selected,
    required this.firstDate,
    required this.lastDate,
    required this.onSelected,
    super.key,
  });

  final DateTime month;
  final DateTime? selected;
  final DateTime firstDate;
  final DateTime lastDate;
  final ValueChanged<DateTime> onSelected;

  static const _rowHeight = AppSize.minTouchTarget;

  @override
  Widget build(BuildContext context) {
    // Monday-first: the blank cells before the 1st.
    final lead = DateTime(month.year, month.month).weekday - 1;
    final days = DateUtils.getDaysInMonth(month.year, month.month);
    final rows = ((lead + days) / 7).ceil();
    final chosen = selected;
    final chosenIndex =
        chosen != null &&
            chosen.year == month.year &&
            chosen.month == month.month
        ? lead + chosen.day - 1
        : null;
    final today = DateUtils.dateOnly(DateTime.now());

    return LayoutBuilder(
      builder: (context, constraints) {
        final cell = constraints.maxWidth / 7;
        Offset centreOf(int index) =>
            Offset((index % 7 + 0.5) * cell, (index ~/ 7 + 0.5) * _rowHeight);

        return SizedBox(
          height: rows * _rowHeight,
          child: Stack(
            children: [
              if (chosenIndex != null)
                _SelectionCircle(
                  centre: centreOf(chosenIndex),
                  diameter:
                      (cell < _rowHeight ? cell : _rowHeight) - AppSpace.x1,
                ),
              for (var day = 1; day <= days; day++)
                Positioned(
                  left: ((lead + day - 1) % 7) * cell,
                  top: ((lead + day - 1) ~/ 7) * _rowHeight,
                  width: cell,
                  height: _rowHeight,
                  child: _Day(
                    date: DateTime(month.year, month.month, day),
                    selected: chosenIndex == lead + day - 1,
                    today: today == DateTime(month.year, month.month, day),
                    enabled: _inRange(DateTime(month.year, month.month, day)),
                    onSelected: onSelected,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  bool _inRange(DateTime date) =>
      !date.isBefore(firstDate) && !date.isAfter(lastDate);
}

/// The chosen day's circle, gliding to wherever the choice moves.
class _SelectionCircle extends StatelessWidget {
  const _SelectionCircle({required this.centre, required this.diameter});

  final Offset centre;
  final double diameter;

  @override
  Widget build(BuildContext context) {
    final circle = RepaintBoundary(
      child: SizedBox.square(
        dimension: diameter,
        child: DecoratedBox(
          decoration: ShapeDecoration(
            color: Theme.of(context).colorScheme.primary,
            shape: const CircleBorder(),
          ),
        ),
      ),
    );
    final corner = Offset(diameter / 2, diameter / 2);

    // The spring moves a transform, not the stack's layout.
    return Positioned(
      left: 0,
      top: 0,
      child: MediaQuery.disableAnimationsOf(context)
          ? Transform.translate(offset: centre - corner, child: circle)
          : MotionBuilder<Offset>(
              motion: AppMotion.chrome,
              converter: MotionConverter.offset,
              value: centre,
              builder: (context, position, child) =>
                  Transform.translate(offset: position - corner, child: child),
              child: circle,
            ),
    );
  }
}

class _Day extends StatelessWidget {
  const _Day({
    required this.date,
    required this.selected,
    required this.today,
    required this.enabled,
    required this.onSelected,
  });

  final DateTime date;
  final bool selected;
  final bool today;
  final bool enabled;
  final ValueChanged<DateTime> onSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = switch ((selected, enabled, today)) {
      (true, _, _) => scheme.onPrimary,
      (_, false, _) => scheme.onSurface.withValues(alpha: 0.38),
      (_, _, true) => context.lakbayan.textOnLightGreen,
      _ => scheme.onSurface,
    };

    return Semantics(
      button: enabled,
      selected: selected,
      label: MaterialLocalizations.of(context).formatFullDate(date),
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? () => onSelected(date) : null,
        child: Center(
          child: AnimatedDefaultTextStyle(
            duration: AppMotion.edge,
            style: AppTypography.labelLarge.copyWith(color: color),
            child: Text("${date.day}"),
          ),
        ),
      ),
    );
  }
}
