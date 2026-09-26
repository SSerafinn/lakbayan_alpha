import "package:animations/animations.dart";
import "package:flutter/material.dart";
import "package:motor/motor.dart";

import "../../theme/app_dimens.dart";
import "../../theme/app_icons.dart";
import "../../theme/app_motion.dart";
import "../../theme/app_typography.dart";
import "../../theme/lakbayan_colors.dart";
import "bar_item_group.dart";

/// One month of days to pick from, inline where the date is being chosen
/// rather than in a dialog over it.
///
/// **Anatomy.** The month's name with the previous and next months as one
/// bar group; the weekday initials; the days in weeks from Monday. The chosen
/// day is a solid green circle with a white numeral (selection, doc 03); today
/// is its numeral in link green; days outside [firstDate] and [lastDate] are
/// faint and inert.
///
/// **Motion.** The circle glides from the old day to the new one on
/// `AppMotion.chrome`, so the eye follows the choice. Months turn along a
/// horizontal shared axis, forward to the right and back to the left. Under
/// reduced motion the circle moves at once and months cross-fade.
///
/// **Cost.** The grid is at most 42 cells, built once per month; a tap
/// rebuilds the grid, and the glide repaints only the circle behind a
/// `RepaintBoundary`.
class MonthCalendar extends StatefulWidget {
  const MonthCalendar({
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
  State<MonthCalendar> createState() => _MonthCalendarState();
}

/// A month turning is a step along an axis, longer than a fade and shorter
/// than a page: declared here, not in `AppMotion`, because only this widget
/// pages months (PREFERENCES, motion).
const _monthTurn = Durations.medium2;

DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

class _MonthCalendarState extends State<MonthCalendar> {
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
    // The platform's own names, in the phone's language; weeks run from
    // Monday, so Sunday's initial moves to the end.
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
            firstDate: _dateOnly(widget.firstDate),
            lastDate: _dateOnly(widget.lastDate),
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
    final today = _dateOnly(DateTime.now());

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

    // One Positioned at the origin and a translate inside it: the spring
    // moves a transform, not the stack's layout.
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
    final label = "${date.day}";

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
            child: Text(label),
          ),
        ),
      ),
    );
  }
}
