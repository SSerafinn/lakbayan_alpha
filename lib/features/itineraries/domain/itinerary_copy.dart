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

/// "Oct 14": the month first, as a trip's dates are read (2026-10-23).
String shortDate(DateTime date) => "${_months[date.month - 1]} ${date.day}";

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

/// "Oct 14 to 15", "Oct 30 to Nov 2", "Oct 14", or null when the trip has no
/// dates. Callers choose their undated state; Add to Trip uses a stop count.
String? datePhrase(Itinerary itinerary) {
  final start = itinerary.startDate;
  final end = itinerary.endDate;
  if (start == null && end == null) return null;
  if (start != null && end != null && !_sameDay(start, end)) {
    return start.month == end.month
        ? "${shortDate(start)} to ${end.day}"
        : "${shortDate(start)} to ${shortDate(end)}";
  }
  return shortDate(start ?? end!);
}

/// "4 stops" or "1 stop".
String stopsPhrase(int count) => "$count stop${count == 1 ? "" : "s"}";

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
