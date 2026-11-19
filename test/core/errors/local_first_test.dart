import "dart:async";

import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";
import "package:lakbayan/core/errors/local_first.dart";
import "package:lakbayan/core/models/destination.dart";
import "package:lakbayan/features/destinations/domain/destination_providers.dart";

import "../../support/fake_destination_repository.dart";
import "../../support/flaky_destination_repository.dart";

/// Which of its three a section would build for [value].
String shown(AsyncValue<Object?> value) => value.whenLocalFirst(
  data: (_) => "data",
  error: (_, _) => "error",
  loading: () => "loading",
);

/// The same through Riverpod's own `when`, as the screens read it before.
String shownByWhen(AsyncValue<Object?> value) => value.when(
  skipError: true,
  data: (_) => "data",
  error: (_, _) => "error",
  loading: () => "loading",
);

/// The states a real provider passes through, in the pinned Riverpod: the
/// helpers are tested against those rather than against hand-made values.
void main() {
  final callao = testDestination(id: "callao", name: "Callao Cave");

  /// Every place as a listener the test drives, and [homeResults] derived
  /// from it, held open as Explore holds them. [retries] is Riverpod's
  /// default retry, as the app has it; off, a failure is final at once.
  ({ProviderContainer container, StreamController<List<Destination>> live})
  listening({bool retries = true}) {
    final live = StreamController<List<Destination>>.broadcast();
    addTearDown(live.close);
    final container = ProviderContainer(
      retry: retries ? ProviderContainer.defaultRetry : (_, _) => null,
      overrides: [
        destinationRepositoryProvider.overrideWithValue(
          FlakyDestinationRepository([callao], liveAll: live),
        ),
      ],
    );
    addTearDown(container.dispose);
    container.listen(homeResultsProvider, (_, _) {});
    return (container: container, live: live);
  }

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  group("a failure after a value", () {
    test("while Riverpod retries, the value stands", () async {
      final (:container, :live) = listening();
      live.add([callao]);
      await settle();
      live.addError(refused);
      await settle();

      final source = container.read(allDestinationsProvider);
      // Why the helpers exist: retrying reads as loading, so `when` would
      // build its spinner, and `whenData` drops the value.
      expect(source, isA<AsyncLoading<List<Destination>>>());
      expect(source.hasValue, isTrue);
      expect(shownByWhen(source), "loading");
      expect(source.whenData((all) => all).hasValue, isFalse);

      expect(shown(source), "data");
      final derived = container.read(homeResultsProvider);
      expect(shown(derived), "data");
      expect(derived.value, [callao]);
    });

    test("once the retries give up, it still stands", () async {
      final (:container, :live) = listening(retries: false);
      live.add([callao]);
      await settle();
      live.addError(refused);
      await settle();

      final source = container.read(allDestinationsProvider);
      expect(source, isA<AsyncError<List<Destination>>>());
      expect(shown(source), "data");
      expect(container.read(homeResultsProvider).value, [callao]);
    });
  });

  group("a failure with nothing on the phone", () {
    test("shows at once, not after the retries", () async {
      final (:container, :live) = listening();
      live.addError(refused);
      await settle();

      final source = container.read(allDestinationsProvider);
      expect(shownByWhen(source), "loading");
      expect(shown(source), "error");
      final derived = container.read(homeResultsProvider);
      expect(shown(derived), "error");
      expect(derived.error, refused);
    });

    test("shows loading while Try again runs", () async {
      final (:container, :live) = listening(retries: false);
      live.addError(refused);
      await settle();
      expect(shown(container.read(homeResultsProvider)), "error");

      container.invalidate(allDestinationsProvider);

      expect(shown(container.read(allDestinationsProvider)), "loading");
      expect(shown(container.read(homeResultsProvider)), "loading");
    });
  });

  test("a value being replaced for changed inputs shows loading", () async {
    final container = ProviderContainer(
      overrides: [
        destinationRepositoryProvider.overrideWithValue(
          FakeDestinationRepository([callao]),
        ),
      ],
    );
    addTearDown(container.dispose);
    container.listen(browseCategoryStreamProvider, (_, _) {});
    container
        .read(browseCategoryProvider.notifier)
        .select(DestinationCategory.nature.name);
    await settle();
    expect(shown(container.read(browseCategoryStreamProvider)), "data");

    // Nature's places are not an answer for churches.
    container
        .read(browseCategoryProvider.notifier)
        .select(DestinationCategory.church.name);
    final replacing = container.read(browseCategoryStreamProvider);
    expect(replacing.value, [callao]);
    expect(shown(replacing), "loading");
  });
}
