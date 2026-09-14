import "package:lakbayan/core/models/destination.dart";
export "package:lakbayan/features/destinations/data/fake_destination_repository.dart";

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
  GeoPoint2 coords = const GeoPoint2(lat: 17.7, lng: 121.8),
}) => Destination(
  id: id,
  name: name ?? id,
  slug: id,
  town: town,
  category: category,
  description: "A place in Cagayan.",
  // No images: StorageImage would reach for Firebase Storage, which is not
  // bound in a widget test. The placeholder path is what renders.
  coords: coords,
  popular: popular,
  featured: featured,
  hasAR: hasAR,
  status: status,
);
