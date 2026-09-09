import "dart:convert";

import "package:hive_ce_flutter/hive_flutter.dart";

import "../domain/offline_bundle.dart";

/// What this device has downloaded, and at which version.
///
/// An interface so tests get [InMemoryDownloadStore] rather than a temp
/// directory and a Hive box — the same arrangement as `AppPreferences`.
abstract interface class DownloadStore {
  DownloadRecord? recordFor(String townId);
  List<DownloadRecord> get all;

  /// Only ever called after a download finished **completely**.
  Future<void> save(DownloadRecord record);

  Future<void> remove(String townId);
}

/// Hive-backed, storing JSON in a `Box<dynamic>`.
///
/// JSON rather than a generated `TypeAdapter`: the record is four fields, and a
/// typed adapter would add a registrar and a codegen step to the app's startup
/// path for no gain. It also means a record written by an older build decodes
/// or fails loudly instead of throwing inside Hive's binary reader.
class HiveDownloadStore implements DownloadStore {
  const HiveDownloadStore(this._box);

  static const boxName = "downloads";

  final Box<dynamic> _box;

  static Future<HiveDownloadStore> open() async {
    await Hive.initFlutter();
    return HiveDownloadStore(await Hive.openBox<dynamic>(boxName));
  }

  @override
  DownloadRecord? recordFor(String townId) {
    final raw = _box.get(townId);
    if (raw is! String) return null;
    try {
      return DownloadRecord.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      // A record this build cannot read is treated as absent, which offers a
      // re-download. The alternative is a crash on a screen whose whole job is
      // to work when nothing else does.
      return null;
    }
  }

  @override
  List<DownloadRecord> get all => _box.keys
      .map((k) => recordFor(k as String))
      .whereType<DownloadRecord>()
      .toList();

  @override
  Future<void> save(DownloadRecord record) =>
      _box.put(record.townId, jsonEncode(record.toJson()));

  @override
  Future<void> remove(String townId) => _box.delete(townId);
}

/// For tests, and for the case where Hive would not open.
class InMemoryDownloadStore implements DownloadStore {
  InMemoryDownloadStore([Iterable<DownloadRecord> initial = const []])
    : _records = {for (final r in initial) r.townId: r};

  final Map<String, DownloadRecord> _records;

  @override
  DownloadRecord? recordFor(String townId) => _records[townId];

  @override
  List<DownloadRecord> get all => _records.values.toList();

  @override
  Future<void> save(DownloadRecord record) async =>
      _records[record.townId] = record;

  @override
  Future<void> remove(String townId) async => _records.remove(townId);
}
