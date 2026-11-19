import "package:freezed_annotation/freezed_annotation.dart";

import "destination.dart";
import "timestamp_converter.dart";

part "app_settings.freezed.dart";
part "app_settings.g.dart";

/// Current shape of the three `settings` documents. Bump alongside
/// `docs/DATA_MODEL.md` whenever it changes.
const settingsSchemaVersion = 2;

/// `settings/taxonomy`: the municipality list the CMS offers for a
/// destination's town, and the categories the province added beyond the six.
///
/// The towns are mostly the CMS's concern, mirrored here so the contract lives
/// in one place on each side. The app reads [categories], to name and draw a
/// place whose category is one of them (`PlaceKind`).
@freezed
abstract class TaxonomySettings with _$TaxonomySettings {
  const factory TaxonomySettings({
    @Default(<String>[]) List<String> towns,

    /// Beyond the six, in the order they were added.
    @Default(<CustomCategory>[]) List<CustomCategory> categories,
  }) = _TaxonomySettings;

  factory TaxonomySettings.fromJson(Map<String, dynamic> json) =>
      _$TaxonomySettingsFromJson(json);
}

/// A category the province added in the CMS (`settings/taxonomy`).
///
/// It brings what the app needs to draw it with no release: an icon from the
/// fixed list in `design/category-glyphs.json` ([glyph], see
/// `CategoryGlyphs`) and the colours of one of the six ([look]).
@freezed
abstract class CustomCategory with _$CustomCategory {
  const factory CustomCategory({
    /// What a destination's `category` holds. Never changes.
    required String id,

    /// One place: "Resort", read as "Resort in Santa Ana".
    required String name,

    /// On the chips: "Resorts".
    required String plural,

    /// A name from `design/category-glyphs.json`.
    @Default("") String glyph,

    /// Whose colours it takes. One the app does not know reads as nature's.
    @JsonKey(unknownEnumValue: DestinationCategory.nature)
    @Default(DestinationCategory.nature)
    DestinationCategory look,
  }) = _CustomCategory;

  factory CustomCategory.fromJson(Map<String, dynamic> json) =>
      _$CustomCategoryFromJson(json);
}

/// `settings/app`: what the province says to visitors directly — how to
/// reach the tourism office, who to call in an emergency, and a notice for
/// the top of Explore.
///
/// Read by Explore for its notice on every launch, which is also what keeps
/// the emergency lines cached for Help offline (`appSettingsProvider`).
@freezed
abstract class AppSettings with _$AppSettings {
  const factory AppSettings({
    OfficeContact? contact,

    /// In display order.
    @Default(<Hotline>[]) List<Hotline> hotlines,

    /// Null when there is no notice.
    Announcement? announcement,
  }) = _AppSettings;

  factory AppSettings.fromJson(Map<String, dynamic> json) =>
      _$AppSettingsFromJson(json);
}

/// The tourism office. Every field free text and optional, shown as written.
@freezed
abstract class OfficeContact with _$OfficeContact {
  const factory OfficeContact({
    String? office,
    String? phone,
    String? email,
    String? hours,
    String? address,
  }) = _OfficeContact;

  factory OfficeContact.fromJson(Map<String, dynamic> json) =>
      _$OfficeContactFromJson(json);
}

/// One emergency or help line: "MDRRMO Peñablanca", "0917 …".
@freezed
abstract class Hotline with _$Hotline {
  const factory Hotline({required String label, required String number}) =
      _Hotline;

  factory Hotline.fromJson(Map<String, dynamic> json) =>
      _$HotlineFromJson(json);
}

/// A short notice for the top of Explore: a closure, a typhoon advisory.
@freezed
abstract class Announcement with _$Announcement {
  const Announcement._();

  const factory Announcement({
    required String text,

    /// Past this, the notice is over. Null runs until it is removed.
    @TimestampConverter() DateTime? until,
  }) = _Announcement;

  factory Announcement.fromJson(Map<String, dynamic> json) =>
      _$AnnouncementFromJson(json);

  /// Whether to show it at [now]. An empty notice is never shown, whatever
  /// its date — a cleared text field must not leave an empty banner behind.
  bool isLiveAt(DateTime now) =>
      text.trim().isNotEmpty && (until == null || now.isBefore(until!));
}

/// `settings/policies`: the privacy policy and terms of use, as the province
/// wrote them. Plain text; blank lines separate paragraphs.
@freezed
abstract class PolicySettings with _$PolicySettings {
  const factory PolicySettings({
    @Default("") String privacy,
    @Default("") String terms,

    /// When each text last changed: the "last updated" date a reader sees.
    @TimestampConverter() DateTime? privacyUpdatedAt,
    @TimestampConverter() DateTime? termsUpdatedAt,
  }) = _PolicySettings;

  factory PolicySettings.fromJson(Map<String, dynamic> json) =>
      _$PolicySettingsFromJson(json);
}
