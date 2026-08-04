import "package:lakbayan/core/models/destination.dart";
import "package:lakbayan/features/destinations/data/destination_repository.dart";

/// In-memory [DestinationRepository] so screens can be driven without Firebase.
///
/// Mirrors the real repository's contract in one respect that matters: it only
/// ever returns published destinations, because `firestore.rules` makes that
/// the only thing a client can read.
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
  Stream<Destination?> watchById(String id) => Stream.value(
        _published.where((d) => d.id == id).firstOrNull,
      );

  @override
  Stream<List<Segment>> watchSegments(String destinationId) =>
      Stream.value(segments[destinationId] ?? const []);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// A published destination with sane defaults, so each test only states what it
/// actually cares about.
Destination testDestination({
  required String id,
  String? name,
  String town = "Peñablanca",
  DestinationCategory category = DestinationCategory.nature,
  bool popular = false,
  bool featured = false,
  bool hasAR = false,
  DestinationStatus status = DestinationStatus.published,
}) =>
    Destination(
      id: id,
      name: name ?? id,
      slug: id,
      town: town,
      category: category,
      description: "A place in Cagayan.",
      // No images: StorageImage would reach for Firebase Storage, which is not
      // bound in a widget test. The placeholder path is what renders.
      coords: const GeoPoint2(lat: 17.7, lng: 121.8),
      popular: popular,
      featured: featured,
      hasAR: hasAR,
      status: status,
    );
