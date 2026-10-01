import "dart:io";

import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:flutter_test/flutter_test.dart";
import "package:lakbayan/core/theme/app_theme.dart";
import "package:lakbayan/features/destinations/data/sample_destinations.dart";
import "package:lakbayan/features/destinations/data/sample_photo_credits.dart";
import "package:lakbayan/features/profile/presentation/sample_photo_credits_sheet.dart";

/// The sample photographs are other people's work, used under licences that
/// require credit. Three things have to agree for that credit to be real: the
/// files in the folder, the list the app shows, and the document beside the
/// files. These tests are what stops them drifting apart.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const folder = "assets/images/samples";

  final used = <String>{
    for (final place in sampleDestinations) ...place.images,
  };
  final credited = <String>{for (final c in samplePhotoCredits) c.asset};

  group("every photograph is accounted for", () {
    test("each one a sample place uses has a credit", () {
      expect(used.difference(credited), isEmpty, reason: "uncredited photos");
    });

    test("no credit is left over for a photograph nothing uses", () {
      expect(credited.difference(used), isEmpty, reason: "orphaned credits");
    });

    test("no photograph is credited twice", () {
      expect(credited, hasLength(samplePhotoCredits.length));
    });

    test("nothing sits in the folder uncredited", () {
      // A file dropped in here ships in the app. If it is not in the list,
      // it ships without its author's name on it.
      final onDisk = Directory(folder)
          .listSync()
          .whereType<File>()
          .map((f) => f.path.replaceAll(r"\", "/"))
          .where((path) => !path.endsWith(".md"))
          .toSet();

      expect(onDisk, credited);
    });
  });

  group("each credit is complete", () {
    for (final credit in samplePhotoCredits) {
      test(credit.place, () {
        expect(credit.author.trim(), isNotEmpty);
        expect(credit.licence.trim(), isNotEmpty);
        expect(
          Uri.parse(credit.source).host,
          "commons.wikimedia.org",
          reason: "the original, where the licence can be checked",
        );
        // A Creative Commons licence asks for a link to its text. Public
        // domain has no text to link.
        if (credit.licence.startsWith("CC ")) {
          expect(credit.licenceUrl, startsWith("https://creativecommons.org/"));
        }
      });
    }
  });

  group("the files", () {
    test("are bundled, not just present on disk", () async {
      // An asset directory is not recursive: `assets/images/` in pubspec
      // does not reach `assets/images/samples/`. Without its own line every
      // sample card would quietly fall back to the placeholder.
      for (final path in used) {
        final data = await rootBundle.load(path);
        expect(data.lengthInBytes, greaterThan(0), reason: path);
      }
    });

    test("are JPEGs small enough to carry", () {
      // These ship in every build, including releases that never show them.
      // A 6 MB original dropped in by mistake would cost every user that.
      var total = 0;
      for (final path in used) {
        final bytes = File(path).readAsBytesSync();
        expect(bytes.take(2), [0xFF, 0xD8], reason: "$path is not a JPEG");
        expect(bytes.length, lessThan(300 * 1024), reason: path);
        total += bytes.length;
      }
      expect(total, lessThan(2 * 1024 * 1024));
    });
  });

  group("CREDITS.md beside the files", () {
    final document = File("$folder/CREDITS.md").readAsStringSync();

    for (final credit in samplePhotoCredits) {
      test("names ${credit.place}", () {
        expect(document, contains(credit.asset.split("/").last));
        expect(document, contains(credit.author));
        expect(document, contains(credit.source));
      });
    }
  });

  test("Anguib Beach keeps the placeholder", () {
    // Deliberate: no freely licensed photograph of it exists, and another
    // beach under its name would be a small lie. If one is ever found, this
    // test should change along with the credit list — not be worked around.
    final anguib = sampleDestinations.singleWhere(
      (d) => d.id == "anguib-beach",
    );

    expect(anguib.images, isEmpty);
  });

  group("the credits sheet", () {
    Future<void> open(WidgetTester tester) async {
      // A narrow phone: where a one-line row would cut the credit short.
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showSamplePhotoCredits(context),
                child: const Text("open"),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text("open"));
      await tester.pumpAndSettle();
    }

    testWidgets("shows every author and licence in full", (tester) async {
      await open(tester);

      for (final credit in samplePhotoCredits) {
        await tester.scrollUntilVisible(
          find.text(credit.place),
          200,
          scrollable: find.byType(Scrollable).last,
        );
        // Whole strings, so an ellipsis would fail this: a credit cut off
        // after the author has lost its licence.
        expect(find.text(credit.place), findsOneWidget);
        expect(find.text(credit.author), findsWidgets);
        expect(find.text(credit.licence), findsWidgets);
      }
    });

    testWidgets("nothing overflows on a narrow phone", (tester) async {
      await open(tester);
      await tester.scrollUntilVisible(
        find.text(samplePhotoCredits.last.place),
        200,
        scrollable: find.byType(Scrollable).last,
      );

      expect(tester.takeException(), isNull);
    });
  });
}
