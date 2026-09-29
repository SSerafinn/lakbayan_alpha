import "package:freezed_annotation/freezed_annotation.dart";

part "guide.freezed.dart";
part "guide.g.dart";

/// `guides/{id}`: a real local guide, listed by the province.
///
/// The app complements guides, never replaces them, so this is the one place
/// it hands somebody on to a person. Readable only when signed in
/// (`firestore.rules`): every row is somebody's contact details. No status
/// field and no draft state; see `docs/DATA_MODEL.md`.
@freezed
abstract class Guide with _$Guide {
  const factory Guide({
    required String id,
    required String name,

    /// The municipality they work from.
    required String town,

    /// Lowercase, e.g. `["caving", "birdwatching"]`.
    @Default(<String>[]) List<String> specialties,

    /// Free text: a phone number, an email, or both.
    required String contact,

    /// Accredited by the province.
    @Default(false) bool verified,
    @Default(false) bool featured,
  }) = _Guide;

  factory Guide.fromJson(Map<String, dynamic> json) => _$GuideFromJson(json);
}
