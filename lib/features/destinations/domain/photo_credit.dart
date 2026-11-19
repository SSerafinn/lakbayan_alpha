import "../../../core/models/destination.dart";

// What a photo of a place says about who made it. A Commons photo's licence
// asks for its author's name wherever it is shown, so this is the line the
// photo carries. `docs/DATA_MODEL.md` (Changes in v5) has the contract.

/// The line under a photo, "Photo: Patrickroque01 / CC BY-SA 4.0", or null
/// when nothing was recorded, so a photo with no credit carries no empty
/// label.
///
/// The licence is named only when it is a public one ([isPublicLicence]). A
/// permission note such as "Province-owned; approved for the app" records
/// how the photo was cleared; it is not a notice for a visitor, so a
/// province photo reads "Photo: Cagayan Provincial Tourism Office".
///
/// **The CMS previews this line** (`cms/src/types/photo-credit.ts`), and both
/// assert `cms/src/types/photo-credit-cases.json`; change the two together.
String? photoCreditLine(ImageCredit? credit) {
  final who = credit?.credit?.trim() ?? "";
  final licence = credit?.licence?.trim() ?? "";
  final parts = [
    if (who.isNotEmpty) who,
    if (isPublicLicence(licence)) licence,
  ];
  return parts.isEmpty ? null : "Photo: ${parts.join(" / ")}";
}

/// Whether [licence] names a public licence a visitor may be shown: Creative
/// Commons ("CC BY 2.0", "CC0 1.0", "Creative Commons Attribution") or the
/// public domain. Anything else is read as a permission note.
bool isPublicLicence(String licence) => _public.hasMatch(licence.trim());

final _public = RegExp(
  r"^(cc0?|creative commons|public[ -]domain)\b",
  caseSensitive: false,
);
