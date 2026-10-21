import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";
import "package:lakbayan/core/models/destination.dart";
import "package:lakbayan/core/models/exhibit.dart";
import "package:lakbayan/features/destinations/domain/destination_providers.dart";
import "package:lakbayan/features/offline/domain/offline_bundle.dart";
import "package:lakbayan/features/offline/domain/offline_providers.dart";

import "../../support/fake_destination_repository.dart";

/// What a town's download fetches. It mirrors `collectAssetPaths` in
/// `functions/`; the two must name the same objects, or the size the CMS shows
/// and what the phone pulls would differ.
void main() {
  const bundle = OfflineBundle(
    townId: "tuguegarao-city",
    name: "Tuguegarao City",
    tilePackRef: "tiles/tuguegarao-city/pack.pmtiles",
    version: "v1",
    destinationIds: ["museum", "bridge"],
  );

  Future<List<String>> pathsFor(FakeDestinationRepository repo) {
    final container = ProviderContainer(
      overrides: [destinationRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);
    final paths = FutureProvider((ref) => assetPathsFor(ref, bundle));
    return container.read(paths.future);
  }

  test(
    "covers photos, audio-guide recordings and a museum's AR exhibits",
    () async {
      final repo = FakeDestinationRepository(
        [
          testDestination(id: "museum", name: "Cagayan Museum"),
          testDestination(id: "bridge", name: "Buntun Bridge"),
        ],
        segments: const {
          "museum": [
            Segment(
              id: "s1",
              title: "The hall",
              order: 1,
              audioUrl: "destinations/museum/audio/s1.mp3",
            ),
          ],
        },
        exhibits: const {
          "museum": [
            Exhibit(
              id: "e1",
              title: "The bell",
              order: 1,
              markerPath: "ar/museum/markers/e1.webp",
              markerWidthM: 0.3,
              audioUrl: "destinations/museum/audio/e1.m4a",
            ),
            // Read aloud rather than recorded: a marker and nothing else.
            Exhibit(
              id: "e2",
              title: "The founding stone",
              order: 2,
              markerPath: "ar/museum/markers/e2.webp",
              markerWidthM: 0.4,
              ttsText: "Laid in 1890.",
            ),
          ],
        },
      );

      final paths = await pathsFor(repo);

      expect(
        paths,
        containsAll(<String>[
          "ar/museum/markers/e1.webp",
          "ar/museum/markers/e2.webp",
          "destinations/museum/audio/e1.m4a",
          "destinations/museum/audio/s1.mp3",
        ]),
      );
      // And nothing twice, in a stable order.
      expect(paths.toSet(), hasLength(paths.length));
      expect(paths, [...paths]..sort());
    },
  );
}
