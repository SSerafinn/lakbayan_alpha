import "package:freezed_annotation/freezed_annotation.dart";

import "timestamp_converter.dart";

part "destination.freezed.dart";
part "destination.g.dart";

/// Current shape of `destinations` and `segments`. Bump alongside
/// `docs/DATA_MODEL.md` whenever the schema changes, so a client reading a
/// document cached by an older build can detect the mismatch.
const destinationSchemaVersion = 1;

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
  @JsonValue("unknown")
  unknown;

  String get label => switch (this) {
        church => "Churches",
        nature => "Nature",
        heritage => "Heritage",
        museum => "Museums",
        food => "Food",
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
    required String description,
    required GeoPoint2 coords,
    String? history,
    @Default(<String>[]) List<String> images,
    @Default(false) bool popular,
    @Default(false) bool featured,

    /// Ids of related destinations, for "Nearby stops" on the detail screen.
    @Default(<String>[]) List<String> nearby,
    @Default(false) bool hasAR,
    @JsonKey(unknownEnumValue: DestinationStatus.unknown)
    @Default(DestinationStatus.draft)
    DestinationStatus status,
    @Default(destinationSchemaVersion) int schemaVersion,
    @TimestampConverter() DateTime? createdAt,
    @TimestampConverter() DateTime? updatedAt,
  }) = _Destination;

  const Destination._();

  factory Destination.fromJson(Map<String, dynamic> json) =>
      _$DestinationFromJson(json);

  /// The Storage path of the card image, if there is one.
  String? get coverImage => images.isEmpty ? null : images.first;

  /// True when this document was written by a newer client than this build
  /// understands. Callers should degrade gracefully rather than hide the row.
  bool get isNewerSchema => schemaVersion > destinationSchemaVersion;
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

  factory Segment.fromJson(Map<String, dynamic> json) => _$SegmentFromJson(json);

  /// A segment with neither recorded audio nor TTS text cannot be played.
  bool get isPlayable =>
      (audioUrl != null && audioUrl!.isNotEmpty) ||
      (ttsText != null && ttsText!.isNotEmpty);
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
