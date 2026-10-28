import "dart:async";

import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";
import "package:go_router/go_router.dart";
import "package:lakbayan/core/theme/app_theme.dart";
import "package:lakbayan/core/widgets/content/page_dots.dart";
import "package:lakbayan/core/widgets/content/storage_image.dart";
import "package:lakbayan/features/destinations/domain/destination_providers.dart";
import "package:lakbayan/features/destinations/presentation/photo_viewer.dart";

import "../../support/fake_destination_repository.dart";

/// A place's photos full screen (D-19): where it opens, the strip and dots
/// that move between photos, and the way back.
void main() {
  const photos = [
    "destinations/callao/images/1.jpg",
    "destinations/callao/images/2.jpg",
    "destinations/callao/images/3.jpg",
  ];

  late List<int> pages;

  Future<void> pump(
    WidgetTester tester, {
    List<String> images = photos,
    int at = 0,
  }) async {
    pages = [];
    final router = GoRouter(
      initialLocation: "/viewer",
      routes: [
        GoRoute(path: "/", builder: (_, _) => const Text("Place")),
        GoRoute(
          path: "/viewer",
          builder: (_, _) =>
              PhotoViewer(id: "callao", at: at, onPageChanged: pages.add),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          destinationRepositoryProvider.overrideWithValue(
            FakeDestinationRepository([
              testDestination(
                id: "callao",
                name: "Callao Cave",
              ).copyWith(images: images),
            ]),
          ),
          // Storage is not bound in a widget test: the photos stay as their
          // placeholders, which is all the viewer's own behaviour needs.
          storageUrlProvider.overrideWith(
            (ref, path) => Completer<String>().future,
          ),
        ],
        child: MaterialApp.router(theme: buildAppTheme(), routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
  }

  int current(WidgetTester tester) =>
      tester.widget<PageDots>(find.byType(PageDots)).current;

  testWidgets("opens on the photo it was opened from", (tester) async {
    await pump(tester, at: 1);

    expect(current(tester), 1);
    expect(tester.widget<PageDots>(find.byType(PageDots)).count, 3);
  });

  testWidgets("the strip moves to the photo tapped", (tester) async {
    await pump(tester);

    await tester.tap(find.bySemanticsLabel("Photo 3 of 3"));
    await tester.pumpAndSettle();

    expect(current(tester), 2);
    expect(pages.last, 2);
  });

  testWidgets("a swipe moves to the next photo", (tester) async {
    await pump(tester);

    await tester.fling(find.byType(PageView), const Offset(-400, 0), 1000);
    await tester.pumpAndSettle();

    expect(current(tester), 1);
    expect(pages, [1]);
  });

  testWidgets("one photo has no dots or strip", (tester) async {
    await pump(tester, images: const ["destinations/callao/images/1.jpg"]);

    expect(find.byType(PageDots), findsNothing);
    expect(find.bySemanticsLabel("Photo 1 of 1"), findsNothing);
  });

  testWidgets("close goes back", (tester) async {
    await pump(tester);

    await tester.tap(find.byTooltip("Close"));
    await tester.pumpAndSettle();

    expect(find.text("Place"), findsOneWidget);
  });
}
