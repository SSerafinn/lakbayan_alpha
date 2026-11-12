import "../../../core/models/destination.dart";

/// A CMS free-text fact tidied for reading (D-19): times as "8 AM", a
/// leading PHP as ₱, the part after the first comma (or a closing "daily")
/// on its own quieter line, each line starting with a capital. A comma that
/// groups thousands ("₱1,500") is part of the number, not a break. Words stay
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
  final cut = tidy.indexOf(_noteComma);
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

/// Any comma but a thousands separator: one between a digit and exactly
/// three more ("1,500", "1,000,000"), which would otherwise leave "₱1".
final _noteComma = RegExp(r"(?<!\d),|,(?!\d{3}\b)");

String capital(String text) =>
    text.isEmpty ? text : text[0].toUpperCase() + text.substring(1);

/// The longest fee that fits a pill on a photo; a sentence stays on the
/// place's page, in Details.
const _priceLength = 12;

/// What it costs to get in, in the editor's own words ("Free", "₱50"), when
/// that is short enough for a photo and reads as a price: "Free", or words
/// with a number in them. Null otherwise ("Boat hire" is how you get there,
/// not what it costs): a price is shown or it is not there, never guessed.
String? entryPrice(Destination place) {
  final value = tidyFact(place.practical?.entryFee)?.value;
  if (value == null || value.length > _priceLength) return null;
  if (!_digit.hasMatch(value) && value.toLowerCase() != "free") return null;
  return value;
}

final _digit = RegExp(r"\d");
