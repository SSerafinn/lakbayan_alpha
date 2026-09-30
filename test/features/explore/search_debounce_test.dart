import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";
import "package:lakbayan/core/theme/app_theme.dart";
import "package:lakbayan/features/destinations/domain/destination_providers.dart";
import "package:lakbayan/features/explore/domain/home_tab.dart";
import "package:lakbayan/features/explore/presentation/home_chrome_layer.dart";

import "../../support/fake_destination_repository.dart";

/// The search field's text reaches the query only once typing pauses. The
/// wireframe asks for it; Browse had it until search moved into the bar in
/// #77, and it was lost in the move with nothing to notice.
void main() {
  Future<ProviderContainer> pumpShell(WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 850);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final container = ProviderContainer(
      overrides: [
        destinationRepositoryProvider.overrideWithValue(
          FakeDestinationRepository([
            testDestination(id: "callao", name: "Callao Cave"),
            testDestination(id: "palaui", name: "Palaui Island"),
          ]),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: buildAppTheme(),
          home: const Scaffold(
            body: HomeChromeLayer(tab: HomeTab.explore, child: SizedBox()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip("Search"));
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets("typing does not search until it pauses", (tester) async {
    final container = await pumpShell(tester);

    await tester.enterText(find.byType(TextField), "palaui");
    await tester.pump();
    expect(container.read(homeQueryProvider), "");

    await tester.pump(const Duration(milliseconds: 300));
    expect(container.read(homeQueryProvider), "palaui");
  });

  testWidgets("a word typed quickly is one search, not one per letter", (
    tester,
  ) async {
    // What makes it a debounce rather than a delay: the half-typed word
    // never becomes a query at all.
    final container = await pumpShell(tester);
    final seen = <String>[];
    container.listen(homeQueryProvider, (_, next) => seen.add(next));

    await tester.enterText(find.byType(TextField), "pal");
    await tester.pump(const Duration(milliseconds: 150));
    await tester.enterText(find.byType(TextField), "palaui");
    await tester.pump(const Duration(milliseconds: 150));
    expect(seen, isEmpty, reason: "only 150ms since the last keystroke");

    await tester.pump(const Duration(milliseconds: 150));
    expect(seen, ["palaui"]);
  });

  testWidgets("closing search leaves no query behind", (tester) async {
    final container = await pumpShell(tester);

    await tester.enterText(find.byType(TextField), "pal");
    await tester.tap(find.byTooltip("Close search"));
    await tester.pumpAndSettle();
    // Well past the debounce, so a keystroke that escaped the cancel would
    // have landed by now.
    await tester.pump(const Duration(seconds: 1));

    expect(container.read(homeQueryProvider), "");
  });
}
