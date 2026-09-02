import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:hive_ce_flutter/hive_flutter.dart";

/// Device-local flags that survive a relaunch.
///
/// Not user data: nothing here syncs, nothing here is worth a Firestore read,
/// and losing all of it on reinstall is the correct outcome. That is why it is
/// a Hive box rather than a document on `users/{uid}`.
///
/// An interface so tests can substitute [InMemoryPreferences] without standing
/// up Hive — a widget test should not need a temp directory to check which
/// screen it lands on.
abstract interface class AppPreferences {
  /// Whether the landing pages have been through once on this device.
  bool get hasSeenLanding;

  Future<void> markLandingSeen();
}

class HivePreferences implements AppPreferences {
  const HivePreferences(this._box);

  static const boxName = "preferences";
  static const _seenLanding = "seenLanding";

  final Box<dynamic> _box;

  /// Opens the box. Call once, before `runApp`.
  static Future<HivePreferences> open() async {
    await Hive.initFlutter();
    return HivePreferences(await Hive.openBox<dynamic>(boxName));
  }

  @override
  bool get hasSeenLanding =>
      _box.get(_seenLanding, defaultValue: false) as bool;

  @override
  Future<void> markLandingSeen() => _box.put(_seenLanding, true);
}

/// In-memory stand-in for tests and for the case where Hive failed to open.
class InMemoryPreferences implements AppPreferences {
  InMemoryPreferences({bool hasSeenLanding = false})
    : _seenLanding = hasSeenLanding;

  bool _seenLanding;

  @override
  bool get hasSeenLanding => _seenLanding;

  @override
  Future<void> markLandingSeen() async => _seenLanding = true;
}

/// Overridden in `main()` with the real Hive-backed instance.
///
/// **Defaults to null rather than throwing**, for the same reason
/// [firebaseBootstrapStatusProvider] does: widget tests pump the app inside
/// their own `ProviderScope` and override only what they care about. Null reads
/// as "nothing recorded", so the landing page shows — which is the safe
/// default, and keeps every existing test working without knowing this exists.
final appPreferencesProvider = Provider<AppPreferences?>((ref) => null);
