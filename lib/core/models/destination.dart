import "package:freezed_annotation/freezed_annotation.dart";

import "timestamp_converter.dart";

part "destination.freezed.dart";
part "destination.g.dart";

/// Current shape of `destinations` and `segments`. Bump alongside
/// `docs/DATA_MODEL.md` whenever the schema changes, so a client reading a
/// document cached by an older build can detect the mismatch.
const destinationSchemaVersion = 3;

/// What kind of place this is. Drives the filter chips on Explore.
///
/// Serialized as the lowercase name. [unknown] is the fallback for a value
/// written by a newer client — an offline-first app will read documents it does
/// not fully understand, and throwing there would break the whole list.
@JsonEnum(fieldRename: FieldRename.none)
enum DestinationCategory {
  church,
  nature,
  heritage,
  museum,
  food,
  landmark,
  @JsonValue("unknown")
  unknown;

  String get label => switch (this) {
    church => "Churches",
    nature => "Nature",
    heritage => "Heritage",
    museum => "Museums",
    food => "Food",
    landmark => "Landmarks",
    unknown => "Other",
  };
}

/// Publication state. Only [published] documents are readable by non-admins —
/// see `firestore.rules`.
enum DestinationStatus {
  draft,
  published,
  @JsonValue("unknown")
  unknown,
}

/// `destinations/{id}` — the FE↔BE contract in `docs/DATA_MODEL.md`.
@freezed
abstract class Destination with _$Destination {
  const factory Destination({
    required String id,
    required String name,
    required String town,
    @JsonKey(unknownEnumValue: DestinationCategory.unknown)
    required DestinationCategory category,

    /// A finer kind within [category], e.g. "Waterfall" under nature, named
    /// in the CMS's Settings. It takes its category's glyph and colour, so a
    /// new one needs no release. Null for none.
    String? subcategory,
    required String description,
    required GeoPoint2 coords,

    /// Auto-derived from [name] in the CMS. Used in deep links, so changing it
    /// breaks any link already shared.
    @Default("") String slug,
    String? history,
    @Default(<String>[]) List<String> images,
    @Default(false) bool popular,
    @Default(false) bool featured,

    /// May be surfaced in another destination's "Nearby stops". Nearby itself
    /// is computed by distance from [coords] — this only gates inclusion.
    @Default(true) bool nearbyEligible,

    /// Include in the town's offline bundle.
    @Default(true) bool offlineEligible,

    /// Museum sites unlock the AR tab in the CMS.
    @Default(false) bool isMuseum,
    @Default(false) bool hasAR,
    @Default(<String>[]) List<String> tags,
    PracticalInfo? practical,
    @JsonKey(unknownEnumValue: DestinationStatus.unknown)
    @Default(DestinationStatus.draft)
    DestinationStatus status,
    @Default(destinationSchemaVersion) int schemaVersion,
    @TimestampConverter() DateTime? createdAt,
    @TimestampConverter() DateTime? updatedAt,

    /// uid of the last editor. Shown in the CMS list; not used by the app.
    String? updatedBy,
  }) = _Destination;

  const Destination._();

  factory Destination.fromJson(Map<String, dynamic> json) =>
      _$DestinationFromJson(json);

  /// The Storage path of the card image, if there is one.
  String? get coverImage => images.isEmpty ? null : images.first;
}

/// `destinations/{id}/segments/{sid}` — one stop in the audio guide.
///
/// Deliberately has no `status`: visibility is inherited from the parent
/// destination in `firestore.rules`. A second copy here would drift.
@freezed
abstract class Segment with _$Segment {
  const factory Segment({
    required String id,
    required String title,
    required int order,
    String? description,

    /// Storage path to recorded narration. When null, [ttsText] is spoken by
    /// `flutter_tts` instead — the fallback the design and plan both assume.
    String? audioUrl,
    String? ttsText,
  }) = _Segment;

  const Segment._();

  factory Segment.fromJson(Map<String, dynamic> json) =>
      _$SegmentFromJson(json);

  /// A segment with neither recorded audio nor TTS text cannot be played.
  bool get isPlayable =>
      (audioUrl != null && audioUrl!.isNotEmpty) ||
      (ttsText != null && ttsText!.isNotEmpty);
}

/// Visitor-facing practical details. Every field is optional free text set by
/// an editor.
///
/// [openHours] is deliberately a **string**, not structured hours. It is enough
/// to display, but nothing can compute an open/closed state from it — a live
/// "Open now" badge needs per-day structured hours, which is a content-model
/// decision that has not been made. Render the text; do not infer status.
@freezed
abstract class PracticalInfo with _$PracticalInfo {
  const factory PracticalInfo({
    String? entryFee,
    String? openHours,
    String? bestSeason,
    String? accessibility,
  }) = _PracticalInfo;

  factory PracticalInfo.fromJson(Map<String, dynamic> json) =>
      _$PracticalInfoFromJson(json);
}

/// Firestore's `GeoPoint` is awkward to construct in tests and pulls the SDK
/// into pure-Dart code, so coordinates are stored as a plain `{lat, lng}` map —
/// which is what `docs/DATA_MODEL.md` specifies.
@freezed
abstract class GeoPoint2 with _$GeoPoint2 {
  const factory GeoPoint2({required double lat, required double lng}) =
      _GeoPoint2;

  factory GeoPoint2.fromJson(Map<String, dynamic> json) =>
      _$GeoPoint2FromJson(json);
}
