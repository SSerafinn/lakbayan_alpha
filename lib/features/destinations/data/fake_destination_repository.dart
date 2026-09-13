import "../../../core/models/destination.dart";
import "destination_repository.dart";

/// In-memory [DestinationRepository] for tests and the debug preview. Like
/// the real one, it only ever returns published destinations.
class FakeDestinationRepository implements DestinationRepository {
  FakeDestinationRepository(this.destinations, {this.segments = const {}});

  final List<Destination> destinations;
  final Map<String, List<Segment>> segments;

  List<Destination> get _published => destinations
      .where((d) => d.status == DestinationStatus.published)
      .toList();

  @override
  Stream<List<Destination>> watchPopular({int limit = 10}) =>
      Stream.value(_published.where((d) => d.popular).take(limit).toList());

  @override
  Stream<List<Destination>> watchFeatured({int limit = 10}) =>
      Stream.value(_published.where((d) => d.featured).take(limit).toList());

  @override
  Stream<List<Destination>> watchAll({DestinationCategory? category}) =>
      Stream.value(
        category == null
            ? _published
            : _published.where((d) => d.category == category).toList(),
      );

  @override
  Stream<Destination?> watchById(String id) =>
      Stream.value(_published.where((d) => d.id == id).firstOrNull);

  @override
  Stream<List<Segment>> watchSegments(String destinationId) =>
      Stream.value(segments[destinationId] ?? const []);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
