import "dart:async";
import "dart:convert";
import "dart:io";

import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_riverpod/misc.dart" show Override;
import "package:flutter_test/flutter_test.dart";
import "package:go_router/go_router.dart";
import "package:lakbayan/core/models/destination.dart";
import "package:lakbayan/core/theme/app_theme.dart";
import "package:lakbayan/core/widgets/content/storage_image.dart";
import "package:lakbayan/features/destinations/domain/destination_providers.dart";
import "package:lakbayan/features/destinations/domain/photo_credit.dart";
import "package:lakbayan/features/destinations/presentation/destination_detail_screen.dart";
import "package:lakbayan/features/destinations/presentation/photo_viewer.dart";

import "../../support/fake_destination_repository.dart";

/// A photo's credit (v5): what the line says, what a document may hold
/// without costing the place, and where the line shows.
void main() {
  group("photoCreditLine", () {
    // The CMS previews the same line, from the same cases
    // (cms/src/types/photo-credit.test.ts). Read from the repository root,
    // which is where `flutter test` runs.
    final fixture = jsonDecode(
      File("cms/src/types/photo-credit-cases.json").readAsStringSync(),
    ) as Map<String, dynamic>;
    final cases = (fixture["cases"] as List).cast<Map<String, dynamic>>();

    test("has cases to check", () {
      // A moved fixture must not leave an empty group that passes.
      expect(cases.length, greaterThan(10));
    });

    for (final c in cases) {
      final credit = c["credit"] as String?;
      final licence = c["licence"] as String?;
      test("${jsonEncode(credit)} + ${jsonEncode(licence)}", () {
        expect(
          photoCreditLine(ImageCredit(credit: credit, licence: licence)),
          c["line"],
        );
      });
    }

    test("no credit recorded is no line", () {
      expect(photoCreditLine(null), isNull);
    });
  });

  group("imageCredits in a document", () {
    Map<String, dynamic> place(Object? credits) => {
      "id": "callao",
      "name": "Callao Cave",
      "town": "Peñablanca",
      "category": "nature",
      "description": "Seven chambers.",
      "coords": {"lat": 17.7, "lng": 121.8},
      "images": ["destinations/callao/images/PEN-001-01.jpg"],
      "status": "published",
      "imageCredits": ?credits,
    };

    test("reads a credit by the photo's path", () {
      final d = Destination.fromJson(
        place({
          "destinations/callao/images/PEN-001-01.jpg": {
            "credit": "mkirader",
            "licence": "CC BY 2.0",
          },
        }),
      );

      expect(
        d.creditFor("destinations/callao/images/PEN-001-01.jpg"),
        const ImageCredit(credit: "mkirader", licence: "CC BY 2.0"),
      );
      expect(d.creditFor("destinations/callao/images/other.jpg"), isNull);
    });

    test("a document from before v5 has none", () {
      final d = Destination.fromJson(place(null));

      expect(d.imageCredits, isEmpty);
    });

    test("a malformed entry is dropped, not the place", () {
      // `decodeOrSkip` drops a whole destination whose fromJson throws. A
      // credit is a line under a photo and must never cost that much.
      final d = Destination.fromJson(
        place({
          "a.jpg": "Patrickroque01",
          "b.jpg": {"credit": 42, "licence": "CC BY-SA 4.0"},
          "c.jpg": {"credit": "Elmer Domingo"},
          "d.jpg": null,
        }),
      );

      expect(d.imageCredits.keys, ["b.jpg", "c.jpg"]);
      expect(d.creditFor("b.jpg"), const ImageCredit(licence: "CC BY-SA 4.0"));
      expect(d.creditFor("c.jpg"), const ImageCredit(credit: "Elmer Domingo"));
    });

    test("a field that is not a map reads as none", () {
      expect(Destination.fromJson(place("oops")).imageCredits, isEmpty);
      expect(Destination.fromJson(place(["a.jpg"])).imageCredits, isEmpty);
    });

    test("round-trips through JSON", () {
      final d = Destination.fromJson(
        place({
          "destinations/callao/images/PEN-001-01.jpg": {
            "credit": "mkirader",
            "licence": "CC BY 2.0",
          },
        }),
      );

      final again = Destination.fromJson(
        jsonDecode(jsonEncode(d.toJson())) as Map<String, dynamic>,
      );

      expect(again.imageCredits, d.imageCredits);
    });
  });

  group("on screen", () {
    const cover = "destinations/callao/images/PEN-001-01.jpg";
    const second = "destinations/callao/images/1731900000000.webp";
    const third = "destinations/callao/images/1731900000001.webp";

    final callao = testDestination(id: "callao", name: "Callao Cave").copyWith(
      images: const [cover, second, third],
      imageCredits: const {
        cover: ImageCredit(credit: "mkirader", licence: "CC BY 2.0"),
        second: ImageCredit(
          credit: "Cagayan Provincial Tourism Office",
          licence: "Province-owned; approved for the app",
        ),
        // A key whose photo is gone, as an old document may hold.
        "destinations/callao/images/removed.jpg": ImageCredit(credit: "Nobody"),
      },
    );

    List<Override> overrides() => [
      destinationRepositoryProvider.overrideWithValue(
        FakeDestinationRepository([callao]),
      ),
      // Storage is not bound in a widget test: the photos stay as their
      // placeholders, which is all the credit needs.
      storageUrlProvider.overrideWith(
        (ref, path) => Completer<String>().future,
      ),
    ];

    testWidgets("the place's photo carries its credit, page by page", (
      tester,
    ) async {
      tester.view.physicalSize = const Size(400, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: overrides(),
          child: MaterialApp(
            theme: buildAppTheme(),
            home: const Scaffold(body: DestinationDetailScreen(id: "callao")),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text("Photo: mkirader / CC BY 2.0"), findsOneWidget);
      // Read out without the slash.
      expect(
        find.bySemanticsLabel("Photo: mkirader, CC BY 2.0"),
        findsOneWidget,
      );

      // The next photo's credit; its permission note stays off screen.
      await tester.fling(
        find.byType(PageView).first,
        const Offset(-300, 0),
        1000,
      );
      await tester.pumpAndSettle();
      expect(find.text("Photo: mkirader / CC BY 2.0"), findsNothing);
      expect(
        find.text("Photo: Cagayan Provincial Tourism Office"),
        findsOneWidget,
      );
      expect(find.textContaining("Province-owned"), findsNothing);

      // A photo with none carries no line.
      await tester.fling(
        find.byType(PageView).first,
        const Offset(-300, 0),
        1000,
      );
      await tester.pumpAndSettle();
      expect(find.textContaining("Photo:"), findsNothing);
      expect(find.textContaining("Nobody"), findsNothing);
    });

    testWidgets("full screen, under the photo showing", (tester) async {
      final router = GoRouter(
        initialLocation: "/viewer",
        routes: [
          GoRoute(path: "/", builder: (_, _) => const Text("Place")),
          GoRoute(
            path: "/viewer",
            builder: (_, _) => const PhotoViewer(id: "callao", at: 1),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: overrides(),
          child: MaterialApp.router(
            theme: buildAppTheme(),
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text("Photo: Cagayan Provincial Tourism Office"),
        findsOneWidget,
      );

      await tester.tap(find.bySemanticsLabel("Photo 1 of 3"));
      await tester.pumpAndSettle();
      expect(find.text("Photo: mkirader / CC BY 2.0"), findsOneWidget);
      expect(
        find.text("Photo: Cagayan Provincial Tourism Office"),
        findsNothing,
      );
    });
  });
}
