import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";
import "package:lakbayan/core/models/app_settings.dart";
import "package:lakbayan/core/models/destination.dart";
import "package:lakbayan/core/theme/app_icons.dart";
import "package:lakbayan/core/theme/category_glyphs.dart";
import "package:lakbayan/features/destinations/domain/destination_providers.dart";
import "package:lakbayan/features/destinations/domain/place_kind.dart";

import "../../support/fake_destination_repository.dart";

const resort = CustomCategory(
  id: "resort",
  name: "Resort",
  plural: "Resorts",
  glyph: "swimming-pool",
  look: DestinationCategory.nature,
);

Map<String, dynamic> _doc(String category) => {
  "id": "p",
  "name": "Place",
  "town": "Santa Ana",
  "category": category,
  "description": "A place.",
  "coords": {"lat": 18.4, "lng": 122.1},
};

void main() {
  group("reading a destination", () {
    test("a built-in category keeps its enum, keyed by its name", () {
      final d = Destination.fromJson(_doc("church"));
      expect(d.category, DestinationCategory.church);
      expect(d.kindKey, "church");
    });

    test("an added category reads as unknown but keeps its id", () {
      final d = Destination.fromJson(_doc("resort"));
      expect(d.category, DestinationCategory.unknown);
      expect(d.categoryKey, "resort");
      expect(d.kindKey, "resort");
    });
  });

  group("kindForKey", () {
    test("finds the six and the added ones", () {
      expect(
        kindForKey("museum", const []).builtIn,
        DestinationCategory.museum,
      );
      final kind = kindForKey("resort", const [resort]);
      expect(kind.label, "Resorts");
      expect(kind.name, "Resort");
      expect(kind.look, DestinationCategory.nature);
      expect(kind.glyph(), CategoryGlyphs.of("swimming-pool"));
    });

    test("reads a category it cannot place as Other", () {
      final kind = kindForKey("resort", const []);
      expect(kind.isOther, isTrue);
      expect(kind.glyph(), AppIcons.kind(DestinationCategory.unknown));
    });

    test("draws an added kind with an icon it does not know as Other", () {
      final odd = kindForKey("x", const [
        CustomCategory(id: "x", name: "X", plural: "Xs", glyph: "nope"),
      ]);
      expect(odd.glyph(), AppIcons.kind(DestinationCategory.unknown));
    });
  });

  test("an added category's look the app does not know reads as nature's", () {
    final c = CustomCategory.fromJson({
      "id": "y",
      "name": "Y",
      "plural": "Ys",
      "glyph": "sun",
      "look": "volcano",
    });
    expect(c.look, DestinationCategory.nature);
  });

  test("the chips and the filters reach places in an added category", () async {
    final container = ProviderContainer(
      overrides: [
        addedCategoriesProvider.overrideWithValue(const [resort]),
        destinationRepositoryProvider.overrideWithValue(
          FakeDestinationRepository([
            testDestination(
              id: "p",
              category: DestinationCategory.unknown,
            ).copyWith(categoryKey: "resort"),
            testDestination(id: "c", category: DestinationCategory.church),
          ]),
        ),
      ],
    );
    addTearDown(container.dispose);

    expect(container.read(placeKindsProvider).map((k) => k.key), [
      ...PlaceKind.builtIns.map((k) => k.key),
      "resort",
    ]);

    container.listen(homeResultsProvider, (_, _) {});
    container.listen(allDestinationsProvider, (_, _) {});
    await container.read(allDestinationsProvider.future);
    container.read(homeCategoryProvider.notifier).toggle("resort");
    expect(container.read(homeResultsProvider).value?.map((d) => d.id), ["p"]);
  });
}
