import "package:flutter/material.dart" show ThemeMode;
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

  /// System, light or dark. Defaults to following the phone.
  ThemeMode get themeMode;

  Future<void> setThemeMode(ThemeMode mode);

  /// Calmer motion chosen in the app, on top of the phone's own setting.
  bool get reduceMotion;

  Future<void> setReduceMotion(bool value);

  /// Destination ids most recently opened, newest first, at most
  /// [recentlyViewedCap]. A history, not user data: it does not sync.
  List<String> get recentlyViewedIds;

  Future<void> markViewed(String destinationId);

  static const recentlyViewedCap = 8;
}

/// [ids] with [id] moved to the front, capped. Shared by both stores so the
/// two cannot disagree on the order.
List<String> _pushRecent(List<String> ids, String id) => {
  id,
  ...ids.where((other) => other != id),
}.take(AppPreferences.recentlyViewedCap).toList();

class HivePreferences implements AppPreferences {
  const HivePreferences(this._box);

  static const boxName = "preferences";
  static const _seenLanding = "seenLanding";
  static const _themeMode = "themeMode";
  static const _recentlyViewed = "recentlyViewed";
  static const _reduceMotion = "reduceMotion";

  final Box<dynamic> _box;

  /// Opens the box. Call once, before `runApp`.
  static Future<HivePreferences> open() async {
    await Hive.initFlutter();
    final preferences = HivePreferences(await Hive.openBox<dynamic>(boxName));
    final stored = preferences._box.get(_recentlyViewed) as List?;
    if (stored != null) {
      await preferences._box.put(
        _recentlyViewed,
        preferences.recentlyViewedIds,
      );
    }
    return preferences;
  }

  @override
  bool get hasSeenLanding =>
      _box.get(_seenLanding, defaultValue: false) as bool;

  @override
  Future<void> markLandingSeen() => _box.put(_seenLanding, true);

  @override
  ThemeMode get themeMode {
    final name = _box.get(_themeMode) as String?;
    return ThemeMode.values.firstWhere(
      (mode) => mode.name == name,
      orElse: () => ThemeMode.system,
    );
  }

  @override
  Future<void> setThemeMode(ThemeMode mode) => _box.put(_themeMode, mode.name);

  @override
  bool get reduceMotion => _box.get(_reduceMotion, defaultValue: false) as bool;

  @override
  Future<void> setReduceMotion(bool value) => _box.put(_reduceMotion, value);

  @override
  List<String> get recentlyViewedIds =>
      ((_box.get(_recentlyViewed) as List?)?.cast<String>() ?? const <String>[])
          .toSet()
          .take(AppPreferences.recentlyViewedCap)
          .toList();

  @override
  Future<void> markViewed(String destinationId) =>
      _box.put(_recentlyViewed, _pushRecent(recentlyViewedIds, destinationId));
}

/// In-memory stand-in for tests and for the case where Hive failed to open.
class InMemoryPreferences implements AppPreferences {
  InMemoryPreferences({bool hasSeenLanding = false})
    : _seenLanding = hasSeenLanding;

  bool _seenLanding;
  ThemeMode _themeMode = ThemeMode.system;
  List<String> _recentlyViewed = const [];
  bool _reduceMotion = false;

  @override
  bool get hasSeenLanding => _seenLanding;

  @override
  Future<void> markLandingSeen() async => _seenLanding = true;

  @override
  ThemeMode get themeMode => _themeMode;

  @override
  Future<void> setThemeMode(ThemeMode mode) async => _themeMode = mode;

  @override
  bool get reduceMotion => _reduceMotion;

  @override
  Future<void> setReduceMotion(bool value) async => _reduceMotion = value;

  @override
  List<String> get recentlyViewedIds => _recentlyViewed;

  @override
  Future<void> markViewed(String destinationId) async =>
      _recentlyViewed = _pushRecent(_recentlyViewed, destinationId);
}

/// Overridden in `main()` with the real Hive-backed instance.
///
/// **Defaults to null rather than throwing**: widget tests pump the app inside
/// their own `ProviderScope` and override only what they care about. Null reads
/// as "nothing recorded", so the landing page shows — which is the safe
/// default, and keeps every existing test working without knowing this exists.
final appPreferencesProvider = Provider<AppPreferences?>((ref) => null);
