import "package:flutter/foundation.dart";
import "package:riverpod_annotation/riverpod_annotation.dart";

part "map_route.g.dart";

/// A route the Map tab is drawing: stops in visiting order, and the name of
/// whatever they came from.
///
/// Holds **ids**, not coordinates. The map resolves them against the full
/// destination list rather than the filtered results, so picking a category
/// chip cannot silently break a line by hiding one of its stops.
@immutable
class MapRoute {
  const MapRoute({required this.label, required this.destinationIds});

  /// The trip or tour this came from, for the banner over the map.
  final String label;

  final List<String> destinationIds;

  /// A line needs two ends. One stop is a place, not a route.
  bool get isDrawable => destinationIds.length >= 2;
}

/// The route on the Map tab, or null when it is just showing places.
///
/// Separate from [MapSelectedId] because they answer different questions and
/// are set by different gestures: a selection is one pin somebody tapped, a
/// route is a whole trip somebody opened. Tapping the basemap clears the
/// selection; only the banner's dismiss clears the route, because a stray tap
/// while panning should not throw away the thing you came here to look at.
@riverpod
class ActiveMapRoute extends _$ActiveMapRoute {
  @override
  MapRoute? build() => null;

  void show(String label, List<String> destinationIds) =>
      state = MapRoute(label: label, destinationIds: destinationIds);

  void clear() => state = null;
}
