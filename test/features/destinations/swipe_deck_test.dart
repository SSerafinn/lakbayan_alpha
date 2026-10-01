import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:lakbayan/core/models/destination.dart";
import "package:lakbayan/core/theme/app_theme.dart";
import "package:lakbayan/features/destinations/presentation/swipe_deck.dart";

import "../../support/fake_destination_repository.dart";

/// `SwipeDeck` replaced `flutter_card_swiper` in #77, so its gestures are
/// ours to prove now. The deck is 400 wide: a slow drag commits past 30% of
/// that (120px), and any release faster than 700px/s decides regardless.
void main() {
  late List<(String, bool)> decided;
  late SwipeDeckController controller;

  Future<void> pump(WidgetTester tester, {int cards = 3}) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    decided = [];
    controller = SwipeDeckController();
    final deck = <Destination>[
      for (final id in ["callao", "palaui", "piat"].take(cards))
        testDestination(id: id, name: id),
    ];

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
          body: StatefulBuilder(
            // The parent owns the list, as the swipe screen does: a decided
            // card is removed here and the next becomes the front.
            builder: (context, setState) => SizedBox(
              width: 400,
              height: 600,
              child: SwipeDeck(
                cards: deck,
                controller: controller,
                tileFor: (place) => ColoredBox(
                  color: Colors.white,
                  child: Center(child: Text(place.name)),
                ),
                onDecided: (place, {required keep}) => setState(() {
                  decided.add((place.id, keep));
                  deck.remove(place);
                }),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group("the buttons", () {
    testWidgets("Keep decides the front card as kept", (tester) async {
      await pump(tester);
      controller.keep();
      await tester.pumpAndSettle();

      expect(decided, [("callao", true)]);
      expect(find.text("palaui"), findsOneWidget);
    });

    testWidgets("Skip decides it as skipped", (tester) async {
      await pump(tester);
      controller.skip();
      await tester.pumpAndSettle();

      expect(decided, [("callao", false)]);
    });

    testWidgets("a second tap while the card is leaving decides nothing", (
      tester,
    ) async {
      // Without the guard a double tap would decide two cards, the second
      // unseen, or decide the first twice.
      await pump(tester);
      controller.keep();
      controller.keep();
      controller.skip();
      await tester.pumpAndSettle();

      expect(decided, [("callao", true)]);
    });

    testWidgets("an empty deck ignores them", (tester) async {
      await pump(tester, cards: 0);
      controller.keep();
      controller.skip();
      await tester.pumpAndSettle();

      expect(decided, isEmpty);
      expect(tester.takeException(), isNull);
    });
  });

  group("dragging", () {
    Future<void> slowDrag(WidgetTester tester, double dx) async {
      // Well under the fling speed, so distance alone decides.
      await tester.timedDrag(
        find.text("callao"),
        Offset(dx, 0),
        const Duration(seconds: 1),
      );
      await tester.pumpAndSettle();
    }

    testWidgets("right, past the line, keeps", (tester) async {
      await pump(tester);
      await slowDrag(tester, 200);

      expect(decided, [("callao", true)]);
    });

    testWidgets("left, past the line, skips", (tester) async {
      await pump(tester);
      await slowDrag(tester, -200);

      expect(decided, [("callao", false)]);
    });

    testWidgets("short of the line, the card comes back undecided", (
      tester,
    ) async {
      await pump(tester);
      await slowDrag(tester, 80);

      expect(decided, isEmpty);
      expect(find.text("callao"), findsOneWidget);
      // Home, not stranded where the finger let go.
      final front = tester.getCenter(find.text("callao"));
      expect(front.dx, closeTo(200, 1));
    });

    testWidgets("a quick flick decides however short it is", (tester) async {
      await pump(tester);
      await tester.fling(find.text("callao"), const Offset(60, 0), 1500);
      await tester.pumpAndSettle();

      expect(decided, [("callao", true)]);
    });
  });
}
