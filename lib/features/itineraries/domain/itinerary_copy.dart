import "../../../core/models/itinerary.dart";

const _months = [
  "Jan",
  "Feb",
  "Mar",
  "Apr",
  "May",
  "Jun",
  "Jul",
  "Aug",
  "Sep",
  "Oct",
  "Nov",
  "Dec",
];

const _weekdays = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];

/// "14 Oct".
String shortDate(DateTime date) => "${date.day} ${_months[date.month - 1]}";

/// "Saturday", for a heading.
String weekday(DateTime date) => switch (_weekdays[date.weekday - 1]) {
  "Mon" => "Monday",
  "Tue" => "Tuesday",
  "Wed" => "Wednesday",
  "Thu" => "Thursday",
  "Fri" => "Friday",
  "Sat" => "Saturday",
  _ => "Sunday",
};

/// "14 to 15 Oct", "14 Oct", or null when the trip has no dates. Also a trip
/// row's second line: a stop count under a name is a dangling number, and
/// "no dates yet" is a hint dressed as metadata, so neither is shown.
String? datePhrase(Itinerary itinerary) {
  final start = itinerary.startDate;
  final end = itinerary.endDate;
  if (start == null && end == null) return null;
  if (start != null && end != null && !_sameDay(start, end)) {
    return start.month == end.month
        ? "${start.day} to ${shortDate(end)}"
        : "${shortDate(start)} to ${shortDate(end)}";
  }
  return shortDate(start ?? end!);
}

/// "4 stops" or "1 stop".
String stopsPhrase(int count) => "$count stop${count == 1 ? "" : "s"}";

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
