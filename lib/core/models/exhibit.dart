import "package:freezed_annotation/freezed_annotation.dart";

part "exhibit.freezed.dart";
part "exhibit.g.dart";

/// One museum exhibit the AR scanner can recognise:
/// `destinations/{id}/exhibits/{eid}` (D-18).
///
/// The camera looks for [markerPath]'s image — a photo of the exhibit, or of
/// its placard — and [markerWidthM], its real width, is how ARCore judges how
/// far away it is. What a visitor then gets is [title], [description] and
/// [story], with narration that works like an audio-guide stop.
///
/// Visibility follows the parent destination, as segments' does: there is no
/// status field to drift from it.
@freezed
abstract class Exhibit with _$Exhibit {
  const factory Exhibit({
    required String id,
    required String title,

    /// 1-based; the order of the list shown when there is no camera to scan.
    required int order,

    /// Storage path, `/ar/{destId}/markers/{eid}.{ext}`.
    required String markerPath,

    /// The marker's real width in metres. ARCore tracks a marker much sooner
    /// and more steadily when it is told the true size.
    required double markerWidthM,

    /// One line, shown on the card that appears when the exhibit is found.
    String? description,

    /// The exhibit sheet's text. Blank lines separate paragraphs.
    String? story,

    /// Storage path to recorded narration. When null, [ttsText] is spoken.
    String? audioUrl,
    String? ttsText,
  }) = _Exhibit;

  const Exhibit._();

  factory Exhibit.fromJson(Map<String, dynamic> json) =>
      _$ExhibitFromJson(json);

  /// Whether the scanner can look for it: a marker image of a known size.
  bool get isScannable => markerPath.isNotEmpty && markerWidthM > 0;

  bool get hasNarration =>
      (audioUrl?.isNotEmpty ?? false) || (ttsText?.isNotEmpty ?? false);
}
