import "package:riverpod_annotation/riverpod_annotation.dart";

import "../../../core/models/destination.dart";
import "../../../core/prefs/app_preferences.dart";
import "destination_providers.dart";

part "recently_viewed.g.dart";

/// Ids of the places opened most recently, newest first. Seeded from
/// [AppPreferences] and written back on every view; in memory only when the
/// preferences are unavailable.
@Riverpod(keepAlive: true)
class RecentlyViewed extends _$RecentlyViewed {
  @override
  List<String> build() =>
      ref.watch(appPreferencesProvider)?.recentlyViewedIds ?? const [];

  void markViewed(String destinationId) {
    state = [
      destinationId,
      ...state.where((id) => id != destinationId),
    ].take(AppPreferences.recentlyViewedCap).toList();
    ref.read(appPreferencesProvider)?.markViewed(destinationId);
  }
}

/// The recently viewed places that are still published, in view order.
@riverpod
List<Destination> recentlyViewedDestinations(Ref ref) {
  final ids = ref.watch(recentlyViewedProvider);
  final all = ref.watch(allDestinationsProvider).value ?? const [];
  final byId = {for (final destination in all) destination.id: destination};
  return [for (final id in ids) ?byId[id]];
}
