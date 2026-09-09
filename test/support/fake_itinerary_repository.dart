import "package:lakbayan/core/models/itinerary.dart";
import "package:lakbayan/features/itineraries/data/itinerary_repository.dart";

/// In-memory `users/{uid}/itineraries`.
///
/// Keyed by uid as the real one is, so a test that gets the ownership wrong
/// fails here rather than passing and leaving `firestore.rules` to catch it in
/// production.
class FakeItineraryRepository implements ItineraryRepository {
  FakeItineraryRepository([Map<String, List<Itinerary>>? initial])
    : _byUid = {...?initial};

  final Map<String, List<Itinerary>> _byUid;
  int _nextId = 1;

  List<Itinerary> forUid(String uid) => _byUid[uid] ?? const [];

  @override
  Stream<List<Itinerary>> watchAll(String uid) =>
      Stream.value(_byUid[uid] ?? const []);

  @override
  Future<String> create(
    String uid, {
    required String name,
    List<String> destinationIds = const [],
  }) async {
    final id = "it-${_nextId++}";
    _byUid
        .putIfAbsent(uid, () => [])
        .add(Itinerary(id: id, name: name, destinationIds: destinationIds));
    return id;
  }

  @override
  Future<void> rename(String uid, String id, String name) async {
    _replace(uid, id, (it) => it.copyWith(name: name));
  }

  @override
  Future<void> setStops(
    String uid,
    String id,
    List<String> destinationIds,
  ) async {
    _replace(uid, id, (it) => it.copyWith(destinationIds: destinationIds));
  }

  @override
  Future<void> delete(String uid, String id) async =>
      _byUid[uid]?.removeWhere((it) => it.id == id);

  void _replace(String uid, String id, Itinerary Function(Itinerary) change) {
    final list = _byUid[uid];
    if (list == null) return;
    final index = list.indexWhere((it) => it.id == id);
    if (index != -1) list[index] = change(list[index]);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// In-memory `tours`.
class FakeTourRepository implements TourRepository {
  FakeTourRepository([this.tours = const []]);

  final List<Tour> tours;

  @override
  Stream<List<Tour>> watchAll() => Stream.value(tours);

  @override
  Stream<Tour?> watchById(String id) =>
      Stream.value(tours.where((t) => t.id == id).firstOrNull);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
