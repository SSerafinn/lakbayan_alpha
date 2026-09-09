import "package:freezed_annotation/freezed_annotation.dart";

import "../../../core/models/timestamp_converter.dart";

part "offline_bundle.freezed.dart";
part "offline_bundle.g.dart";

/// Whether everything a town needs is actually in Storage.
///
/// **There is no `stale` here on purpose.** `docs/DATA_MODEL.md` lists it in
/// the collection's prose, but the function never writes it — staleness is a
/// verdict *this* side reaches by comparing the version it downloaded against
/// the version in the document. Putting it in this enum would imply the server
/// decides, and then two places would decide.
@JsonEnum(fieldRename: FieldRename.none)
enum BundleStatus {
  /// Something is missing — most often the map pack, uploaded by hand after
  /// `tools/tiles` renders it.
  pending,
  ready,

  /// Written by a newer build than this one. Never throw on it: an
  /// offline-first app reads documents it does not fully understand.
  @JsonValue("unknown")
  unknown,
}

/// `offlineBundles/{townId}` — the manifest a phone reads before downloading.
///
/// Deliberately carries no asset list. The paths are derivable from the
/// destinations and their segments, which the app already reads, and holding a
/// second copy here would let the two drift.
@freezed
abstract class OfflineBundle with _$OfflineBundle {
  const factory OfflineBundle({
    required String townId,
    required String name,
    required String tilePackRef,

    /// Content fingerprint. Compared against what was downloaded to decide
    /// whether a town on disk is out of date.
    required String version,
    @Default(<String>[]) List<String> destinationIds,

    /// Total bytes, assets and map pack together.
    @Default(0) int size,
    @JsonKey(unknownEnumValue: BundleStatus.unknown)
    @Default(BundleStatus.pending)
    BundleStatus status,
    @TimestampConverter() DateTime? generatedAt,
  }) = _OfflineBundle;

  const OfflineBundle._();

  factory OfflineBundle.fromJson(Map<String, dynamic> json) =>
      _$OfflineBundleFromJson(json);

  /// Worth offering as a download. A `pending` bundle is missing files, and
  /// starting it would produce a town with no map and no way to say why.
  bool get isDownloadable => status == BundleStatus.ready;
}

/// What this device has on disk for one town.
///
/// Written **only when a download finished completely**. A half-finished town
/// must not be recorded — the whole promise of a bundle is that nothing is
/// fetched later, and a partial record would break that silently.
@freezed
abstract class DownloadRecord with _$DownloadRecord {
  const factory DownloadRecord({
    required String townId,

    /// The bundle version that was downloaded. Compared against the current
    /// document to detect staleness.
    required String version,
    required int bytes,
    required DateTime completedAt,

    /// Absolute path to the map pack on this device.
    required String packPath,
  }) = _DownloadRecord;

  const DownloadRecord._();

  factory DownloadRecord.fromJson(Map<String, dynamic> json) =>
      _$DownloadRecordFromJson(json);
}

/// How a town on this device compares to the town in Firestore.
enum TownState {
  /// Never downloaded.
  absent,

  /// Downloaded, and the version still matches.
  current,

  /// Downloaded, but the province has edited the town since.
  stale,
}

TownState townStateFor(OfflineBundle bundle, DownloadRecord? record) {
  if (record == null) return TownState.absent;
  return record.version == bundle.version ? TownState.current : TownState.stale;
}
