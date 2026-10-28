import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";
import "package:lakbayan/core/models/guide.dart";
import "package:lakbayan/core/theme/app_theme.dart";
import "package:lakbayan/features/destinations/presentation/explore_sections.dart";
import "package:lakbayan/features/guides/domain/guide_providers.dart";

const _guide = Guide(
  id: "g1",
  name: "Mang Ben",
  town: "Peñablanca",
  // With specialties, the card leads with what they guide rather than how
  // to reach them — so the contact is not on screen at all.
  specialties: ["caving"],
  contact: "0917 123 4567 / 0918 765 4321",
  verified: true,
);

void main() {
  late List<Uri> launched;

  Future<void> pump(
    WidgetTester tester, {
    required Future<bool> Function(Uri uri) launcher,
    List<Guide> guides = const [_guide],
  }) async {
    launched = [];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          guidesProvider.overrideWith((ref) => Stream.value(guides)),
          contactLauncherProvider.overrideWithValue((uri) {
            launched.add(uri);
            return launcher(uri);
          }),
        ],
        child: MaterialApp(
          theme: buildAppTheme(),
          home: const Scaffold(
            body: SingleChildScrollView(child: LocalGuides()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tapGuide(WidgetTester tester) async {
    await tester.tap(find.text("Mang Ben"));
    await tester.pumpAndSettle();
  }

  testWidgets("a tap calls the first number, not both joined", (tester) async {
    await pump(tester, launcher: (_) async => true);
    await tapGuide(tester);

    expect(launched, [Uri.parse("tel:09171234567")]);
  });

  testWidgets("when it works, nothing else is said", (tester) async {
    await pump(tester, launcher: (_) async => true);
    await tapGuide(tester);

    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets("when nothing can take it, the contact is handed over", (
    tester,
  ) async {
    // A tablet with no dialer. The number is not on the card, so without
    // this the tap would leave somebody with nothing at all.
    await pump(tester, launcher: (_) async => false);
    expect(find.textContaining(_guide.contact), findsNothing);
    await tapGuide(tester);

    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.textContaining(_guide.contact), findsOneWidget);
  });

  testWidgets("a launcher that throws is handled the same way", (tester) async {
    // Some platforms throw for a scheme with no handler rather than
    // answering false. That used to escape as an unhandled error.
    await pump(
      tester,
      launcher: (_) async => throw StateError("No activity for tel:"),
    );
    await tapGuide(tester);

    expect(tester.takeException(), isNull);
    expect(find.textContaining(_guide.contact), findsOneWidget);
  });

  testWidgets("the section is not there when there are no guides", (
    tester,
  ) async {
    // Also what a guest sees: the rules only let a signed-in person read
    // somebody's contact details, and `guidesProvider` answers empty.
    await pump(tester, launcher: (_) async => true, guides: const []);

    expect(find.text("Meet a Guide"), findsNothing);
  });
}
