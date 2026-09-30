import "package:flutter_test/flutter_test.dart";
import "package:lakbayan/core/models/itinerary.dart";
import "package:lakbayan/features/itineraries/domain/itinerary_actions.dart";

import "../../support/fake_itinerary_repository.dart";

/// Every write fails, the way one does with no signal and a cold cache.
class _FailingRepository extends FakeItineraryRepository {
  final _offline = StateError("unavailable: no connection");

  @override
  Future<String> create(
    String uid, {
    required String name,
    List<String> destinationIds = const [],
    DateTime? startDate,
    DateTime? endDate,
  }) => Future.error(_offline);

  @override
  Future<void> setStops(String uid, String id, List<String> destinationIds) =>
      Future.error(_offline);

  @override
  Future<void> setDates(
    String uid,
    String id, {
    required DateTime? startDate,
    required DateTime? endDate,
  }) => Future.error(_offline);

  @override
  Future<void> rename(String uid, String id, String name) =>
      Future.error(_offline);

  @override
  Future<void> delete(String uid, String id) => Future.error(_offline);
}

void main() {
  const uid = "u1";
  late FakeItineraryRepository repo;

  setUp(() => repo = FakeItineraryRepository());

  ItineraryActions signedIn([FakeItineraryRepository? with_]) =>
      ItineraryActions(with_ ?? repo, uid);

  group("signed in", () {
    test(
      "create writes under the caller's uid and returns the new id",
      () async {
        final id = await signedIn().create(
          name: "Caves in a day",
          stops: ["callao", "piat"],
          startDate: DateTime(2026, 10, 3),
        );

        expect(id, isNotNull);
        final saved = repo.forUid(uid).single;
        expect(saved.id, id);
        expect(saved.name, "Caves in a day");
        expect(saved.destinationIds, ["callao", "piat"]);
        expect(saved.startDate, DateTime(2026, 10, 3));
        expect(repo.forUid("somebody-else"), isEmpty);
      },
    );

    test("addStop appends, because the order is the route", () async {
      final actions = signedIn();
      final id = (await actions.create(name: "Trip", stops: ["a", "b"]))!;
      final trip = repo.forUid(uid).single;

      expect(await actions.addStop(trip, "c"), isTrue);
      expect(repo.forUid(uid).single.destinationIds, ["a", "b", "c"]);
      expect(repo.forUid(uid).single.id, id);
    });

    test("setStops replaces the whole list, reordering included", () async {
      final actions = signedIn();
      final id = (await actions.create(name: "Trip", stops: ["a", "b", "c"]))!;

      expect(await actions.setStops(id, ["c", "a"]), isTrue);
      expect(repo.forUid(uid).single.destinationIds, ["c", "a"]);
    });

    test("setDates writes both, and null clears one", () async {
      final actions = signedIn();
      final id = (await actions.create(
        name: "Trip",
        startDate: DateTime(2026, 10, 3),
        endDate: DateTime(2026, 10, 5),
      ))!;

      expect(await actions.setDates(id, DateTime(2026, 10, 4), null), isTrue);
      final trip = repo.forUid(uid).single;
      expect(trip.startDate, DateTime(2026, 10, 4));
      expect(trip.endDate, isNull);
    });

    test("rename and delete land", () async {
      final actions = signedIn();
      final id = (await actions.create(name: "Trip"))!;

      expect(await actions.rename(id, "Weekend in Peñablanca"), isTrue);
      expect(repo.forUid(uid).single.name, "Weekend in Peñablanca");

      expect(await actions.delete(id), isTrue);
      expect(repo.forUid(uid), isEmpty);
    });
  });

  group("a failed write", () {
    // The contract the screens rely on: a failure comes back as a value, so
    // it can be shown on the control that caused it. A throw would escape a
    // fire-and-forget tap as an unhandled error instead.
    late ItineraryActions actions;
    const trip = Itinerary(id: "it-1", name: "Trip", destinationIds: ["a"]);

    setUp(() => actions = signedIn(_FailingRepository()));

    test("create reports null rather than throwing", () async {
      expect(await actions.create(name: "Trip"), isNull);
    });

    test("every other write reports false rather than throwing", () async {
      expect(await actions.addStop(trip, "b"), isFalse);
      expect(await actions.setStops("it-1", ["b"]), isFalse);
      expect(
        await actions.setDates("it-1", DateTime(2026, 10, 3), null),
        isFalse,
      );
      expect(await actions.rename("it-1", "New"), isFalse);
      expect(await actions.delete("it-1"), isFalse);
    });
  });

  group("a guest", () {
    // No uid means nowhere to write: `users/{uid}/itineraries` is owner-only.
    late ItineraryActions guest;
    const trip = Itinerary(id: "it-1", name: "Trip");

    setUp(() => guest = ItineraryActions(repo, null));

    test("writes nothing, and says so", () async {
      expect(await guest.create(name: "Trip"), isNull);
      expect(await guest.addStop(trip, "a"), isFalse);
      expect(await guest.setStops("it-1", ["a"]), isFalse);
      expect(
        await guest.setDates("it-1", DateTime(2026, 10, 3), null),
        isFalse,
      );
      expect(await guest.rename("it-1", "New"), isFalse);
      expect(await guest.delete("it-1"), isFalse);
    });

    test("never reaches the repository", () async {
      await guest.create(name: "Trip");
      expect(repo.forUid(""), isEmpty);
      expect(repo.forUid("null"), isEmpty);
    });
  });
}
