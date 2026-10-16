import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";
import "package:lakbayan/core/models/destination.dart";
import "package:lakbayan/core/theme/app_theme.dart";
import "package:lakbayan/features/destinations/domain/destination_providers.dart";
import "package:lakbayan/features/destinations/domain/place_share.dart";
import "package:lakbayan/features/destinations/presentation/destination_detail_screen.dart";

import "../../support/fake_destination_repository.dart";

const _map = "https://www.google.com/maps/search/?api=1&query=17.7%2C121.8";

Destination _place({
  String name = "Callao Cave",
  String town = "Peñablanca",
  String description = "A seven-chambered limestone cave.",
}) => testDestination(
  id: "callao",
  name: name,
  town: town,
).copyWith(description: description);

void main() {
  group("placeShareText", () {
    test("names the place, where it is, a line of it, and a pin", () {
      expect(
        placeShareText(_place()),
        "Callao Cave\n"
        "Peñablanca, Cagayan\n"
        "\n"
        "A seven-chambered limestone cave.\n"
        "\n"
        "$_map",
      );
    });

    test("a blank description drops its paragraph", () {
      expect(
        placeShareText(_place(description: "  \n ")),
        "Callao Cave\nPeñablanca, Cagayan\n\n$_map",
      );
    });

    test("a blank town still says the province", () {
      expect(
        placeShareText(_place(town: " ")),
        startsWith("Callao Cave\nCagayan\n\n"),
      );
    });

    test("a town that already says Cagayan is not told twice", () {
      expect(
        placeShareText(_place(town: "Gonzaga, Cagayan")),
        startsWith("Callao Cave\nGonzaga, Cagayan\n\n"),
      );
    });

    test("a blank name leaves no empty first line", () {
      final place = _place(name: "");
      expect(placeShareText(place), startsWith("Peñablanca, Cagayan\n\n"));
      expect(placeShareSubject(place), isNull);
      expect(placeShareSubject(_place()), "Callao Cave");
    });

    test("the pin is the coordinates, not a search on the name", () {
      final uri = placeMapUri(lat: 18.5497, lng: 122.1436);
      expect(uri.host, "www.google.com");
      expect(uri.path, "/maps/search/");
      expect(uri.queryParameters, {"api": "1", "query": "18.5497,122.1436"});
    });
  });

  group("shortDescription", () {
    test("folds line breaks and runs of spaces", () {
      expect(shortDescription(" One.\n\nTwo   three. "), "One. Two three.");
    });

    test("is null when there is nothing to say", () {
      expect(shortDescription(""), isNull);
      expect(shortDescription(" \n\t "), isNull);
    });

    test("leaves a description within the limit alone", () {
      final exact = "a" * shareDescriptionLimit;
      expect(shortDescription(exact), exact);
    });

    test("cuts a long one at a whole word, with an ellipsis", () {
      // Forty whole words fit in the limit; the forty-first does not.
      final long = List.filled(60, "word").join(" ");
      final short = shortDescription(long)!;
      expect(short.length, lessThanOrEqualTo(shareDescriptionLimit + 1));
      expect(short, endsWith("word…"));
      expect(long, startsWith(short.substring(0, short.length - 1)));
    });

    test("a space exactly at the limit is a clean break", () {
      final text = "${"a" * 10} ${"b" * 10}";
      expect(shortDescription(text, limit: 10), "${"a" * 10}…");
    });

    test("does not stutter punctuation into the ellipsis", () {
      expect(
        shortDescription("The church by the river, built in 1765.", limit: 26),
        "The church by the river…",
      );
      expect(
        shortDescription("Built in 1765. The bells came later.", limit: 16),
        "Built in 1765…",
      );
    });

    test("a single run past the limit is the one hard cut", () {
      expect(shortDescription("a" * 30, limit: 10), "${"a" * 10}…");
    });
  });

  group("Share on Place detail", () {
    Future<void> pump(WidgetTester tester, TextSharer sharer) async {
      tester.view.physicalSize = const Size(400, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            destinationRepositoryProvider.overrideWithValue(
              FakeDestinationRepository([_place()]),
            ),
            textSharerProvider.overrideWithValue(sharer),
          ],
          child: MaterialApp(
            theme: buildAppTheme(),
            home: const Scaffold(body: DestinationDetailScreen(id: "callao")),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets("a tap hands the place to the share sheet as text", (
      tester,
    ) async {
      final shared = <(String, String?)>[];
      await pump(
        tester,
        (text, {subject}) async => shared.add((text, subject)),
      );

      await tester.tap(find.byTooltip("Share"));
      await tester.pumpAndSettle();

      expect(shared, [
        (
          "Callao Cave\n"
              "Peñablanca, Cagayan\n"
              "\n"
              "A seven-chambered limestone cave.\n"
              "\n"
              "$_map",
          "Callao Cave",
        ),
      ]);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets("when the sheet will not open, it says so", (tester) async {
      await pump(
        tester,
        (text, {subject}) async => throw Exception("no share sheet"),
      );

      await tester.tap(find.byTooltip("Share"));
      await tester.pump();

      expect(
        find.text("Couldn't open sharing on this device."),
        findsOneWidget,
      );
    });
  });
}
