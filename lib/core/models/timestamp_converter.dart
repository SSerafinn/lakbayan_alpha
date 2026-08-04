import "package:cloud_firestore/cloud_firestore.dart";
import "package:freezed_annotation/freezed_annotation.dart";

/// Firestore hands back [Timestamp], not [DateTime], and `json_serializable`
/// has no idea what to do with it.
///
/// Also accepts an ISO-8601 string, because a document cached in Hive round-trips
/// through plain JSON and loses the Firestore type.
class TimestampConverter implements JsonConverter<DateTime?, Object?> {
  const TimestampConverter();

  @override
  DateTime? fromJson(Object? json) => switch (json) {
        final Timestamp t => t.toDate(),
        final String s => DateTime.tryParse(s),
        _ => null,
      };

  @override
  Object? toJson(DateTime? date) =>
      date == null ? null : Timestamp.fromDate(date);
}
