import "../../../core/models/destination.dart";

/// A CMS free-text fact tidied for reading (D-19): times as "8 AM", a
/// leading PHP as ₱, the part after the first comma (or a closing "daily")
/// on its own quieter line, each line starting with a capital. Words stay
/// the editor's; nothing is added. Null when the field is empty.
({String value, String? note})? tidyFact(String? raw) {
  final text = raw?.trim() ?? "";
  if (text.isEmpty) return null;
  final tidy = text
      .replaceAllMapped(
        _time,
        (time) =>
            "${time[1]}${time[2] == null ? "" : ":${time[2]}"} "
            "${time[3]!.toUpperCase()}",
      )
      .replaceFirst(_peso, "₱");
  final cut = tidy.indexOf(",");
  var value = cut < 0 ? tidy : tidy.substring(0, cut).trim();
  var note = cut < 0 ? "" : tidy.substring(cut + 1).trim();
  if (note.isEmpty && _daily.hasMatch(value)) {
    value = value.replaceFirst(_daily, "");
    note = "Daily";
  }
  return (value: capital(value), note: note.isEmpty ? null : capital(note));
}

final _time = RegExp(
  r"(\d{1,2})(?::(\d{2}))?\s*(am|pm)\b",
  caseSensitive: false,
);
final _peso = RegExp(r"^PHP\s*", caseSensitive: false);
final _daily = RegExp(r"\s+daily$", caseSensitive: false);

String capital(String text) =>
    text.isEmpty ? text : text[0].toUpperCase() + text.substring(1);

/// The longest fee that fits a pill on a photo; a sentence stays on the
/// place's page, in Details.
const _priceLength = 12;

/// What it costs to get in, in the editor's own words ("Free", "₱50"), when
/// that is short enough for a photo. Null when the CMS has none: a price is
/// shown or it is not there, never guessed.
String? entryPrice(Destination place) {
  final value = tidyFact(place.practical?.entryFee)?.value;
  if (value == null || value.length > _priceLength) return null;
  return value;
}
