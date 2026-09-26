import "package:freezed_annotation/freezed_annotation.dart";

import "timestamp_converter.dart";

part "itinerary.freezed.dart";
part "itinerary.g.dart";

/// `tours/{id}` — the province's own curated tour.
///
/// World-readable and admin-written. There is deliberately no `status`: the
/// rule is `allow read: if true`, so a tour is public the moment it exists and
/// there is no draft state to stage one in. The CMS refuses to save one that is
/// not fit to be read instead.
@freezed
abstract class Tour with _$Tour {
  const factory Tour({
    required String id,
    required String title,
    String? description,

    /// Destination ids, in visiting order. The order **is** the route.
    @Default(<String>[]) List<String> stops,

    /// Storage path.
    String? coverImg,
    @Default(false) bool featured,
    @TimestampConverter() DateTime? createdAt,
    @TimestampConverter() DateTime? updatedAt,
  }) = _Tour;

  const Tour._();

  factory Tour.fromJson(Map<String, dynamic> json) => _$TourFromJson(json);
}

/// `users/{uid}/itineraries/{id}` — a tour somebody built for themselves.
///
/// A separate collection from [Tour] rather than a flag on it: `firestore.rules`
/// gates `tours` on the admin claim, so a visitor cannot write one there, and
/// relaxing that rule would open the province's catalog to anybody with an
/// account. Owner-only in both directions — these are private plans, and even
/// an admin has no business reading what somebody is doing on Saturday.
@freezed
abstract class Itinerary with _$Itinerary {
  const factory Itinerary({
    required String id,
    required String name,

    /// Destination ids, in visiting order — the same shape as [Tour.stops], so
    /// the map draws a route from either without caring which it was handed.
    @Default(<String>[]) List<String> destinationIds,

    /// When the trip runs. Optional: a plan can exist before it has dates.
    /// Part of the contract — see `users/{uid}/itineraries` in
    /// `docs/DATA_MODEL.md`.
    @TimestampConverter() DateTime? startDate,
    @TimestampConverter() DateTime? endDate,
    @TimestampConverter() DateTime? createdAt,
    @TimestampConverter() DateTime? updatedAt,
  }) = _Itinerary;

  const Itinerary._();

  factory Itinerary.fromJson(Map<String, dynamic> json) =>
      _$ItineraryFromJson(json);
}
