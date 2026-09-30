import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:lakbayan/core/theme/app_theme.dart";
import "package:lakbayan/features/itineraries/presentation/trip_dates.dart";

/// `TripDates` reads `DateTime.now()` itself, so these dates are relative to
/// today rather than fixed: a month whose first day is at least ten days out,
/// so every day in it is pickable whenever this runs. A hard-coded date here
/// would start failing on its own one day.
final _month = () {
  final base = DateUtils.dateOnly(DateTime.now()).add(const Duration(days: 40));
  return DateTime(base.year, base.month);
}();

DateTime _day(int day) => DateTime(_month.year, _month.month, day);

const _words = DefaultMaterialLocalizations();

/// A day cell, by the full date its semantics carry — never by its number,
/// which the date fields above can show too.
Finder _cell(DateTime date) => find.byWidgetPredicate(
  (w) => w is Semantics && w.properties.label == _words.formatFullDate(date),
);

/// A date field, by the label its semantics start with.
Finder _field(String label) => find.byWidgetPredicate(
  (w) => w is Semantics && (w.properties.label?.startsWith(label) ?? false),
);

bool _isOpen(WidgetTester tester, String label) =>
    tester.widget<Semantics>(_field(label)).properties.expanded ?? false;

void main() {
  DateTime? start;
  DateTime? end;

  Future<void> pump(WidgetTester tester, {DateTime? from, DateTime? to}) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    start = from;
    end = to;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            // The parent owns the dates, as the itinerary sheet does.
            child: StatefulBuilder(
              builder: (context, setState) => TripDates(
                start: start,
                end: end,
                onChanged: (s, e) => setState(() {
                  start = s;
                  end = e;
                }),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tapField(WidgetTester tester, String label) async {
    await tester.tap(_field(label));
    await tester.pumpAndSettle();
  }

  Future<void> tapDay(WidgetTester tester, DateTime date) async {
    await tester.tap(_cell(date), warnIfMissed: false);
    await tester.pumpAndSettle();
  }

  group("picking", () {
    testWidgets("a start moves straight on to the end", (tester) async {
      await pump(tester, from: _day(10));
      await tapField(tester, "Start date");
      await tapDay(tester, _day(12));

      expect(start, _day(12));
      expect(end, isNull);
      expect(_isOpen(tester, "End date"), isTrue);
      expect(_isOpen(tester, "Start date"), isFalse);
    });

    testWidgets("the end folds the calendar away", (tester) async {
      await pump(tester, from: _day(10));
      await tapField(tester, "End date");
      await tapDay(tester, _day(15));

      expect(start, _day(10));
      expect(end, _day(15));
      expect(_isOpen(tester, "Start date"), isFalse);
      expect(_isOpen(tester, "End date"), isFalse);
    });

    testWidgets("tapping the open field again folds it", (tester) async {
      await pump(tester, from: _day(10));
      await tapField(tester, "Start date");
      expect(_isOpen(tester, "Start date"), isTrue);

      await tapField(tester, "Start date");
      expect(_isOpen(tester, "Start date"), isFalse);
    });
  });

  group("keeping the range whole", () {
    testWidgets("the end cannot fall before the start", (tester) async {
      await pump(tester, from: _day(12));
      await tapField(tester, "End date");

      final before = tester.widget<Semantics>(_cell(_day(11)));
      expect(before.properties.button, isFalse, reason: "not offered");

      await tapDay(tester, _day(11));
      expect(end, isNull);
    });

    testWidgets("a start after the end pulls the end up with it", (
      tester,
    ) async {
      // Otherwise the trip would end before it began.
      await pump(tester, from: _day(10), to: _day(12));
      await tapField(tester, "Start date");
      await tapDay(tester, _day(15));

      expect(start, _day(15));
      expect(end, _day(15));
    });

    testWidgets("a start before the end leaves the end alone", (tester) async {
      await pump(tester, from: _day(10), to: _day(20));
      await tapField(tester, "Start date");
      await tapDay(tester, _day(12));

      expect(start, _day(12));
      expect(end, _day(20));
    });
  });

  testWidgets("months page forward and back", (tester) async {
    await pump(tester, from: _day(10));
    await tapField(tester, "Start date");
    expect(find.text(_words.formatMonthYear(_month)), findsOneWidget);

    final next = DateTime(_month.year, _month.month + 1);
    await tester.tap(find.byTooltip("Next month"));
    await tester.pumpAndSettle();
    expect(find.text(_words.formatMonthYear(next)), findsOneWidget);

    await tester.tap(find.byTooltip("Previous month"));
    await tester.pumpAndSettle();
    expect(find.text(_words.formatMonthYear(_month)), findsOneWidget);
  });
}
