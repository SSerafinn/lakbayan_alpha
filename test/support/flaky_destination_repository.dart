import "dart:async";

import "package:firebase_core/firebase_core.dart";
import "package:lakbayan/core/models/destination.dart";

import "fake_destination_repository.dart";

/// Firestore refusing a read. Not an offline code, so the copy shown is the
/// generic one.
final refused = FirebaseException(
  plugin: "cloud_firestore",
  code: "permission-denied",
  message: "Missing or insufficient permissions.",
);

/// Firestore with no connection and nothing cached.
final unreachable = FirebaseException(
  plugin: "cloud_firestore",
  code: "unavailable",
  message: "The service is currently unavailable.",
);

/// A [FakeDestinationRepository] whose list of every place and whose audio
/// stops can be made to fail with [error], or to hang as a first load on a
/// slow connection does.
///
/// Each stream is made when it is listened to, so flipping a flag and then
/// invalidating the provider is a retry that succeeds; the read counts say
/// whether one happened.
class FlakyDestinationRepository extends FakeDestinationRepository {
  FlakyDestinationRepository(
    super.destinations, {
    super.segments,
    Object? error,
    this.failAll = false,
    this.holdAll = false,
    this.failSegments = false,
    this.liveAll,
    this.liveSegments,
  }) : error = error ?? refused;

  Object error;
  bool failAll;
  bool failSegments;

  /// Every place never arrives: the catalogue is still loading.
  bool holdAll;

  /// When set, every place is this listener instead, as Firestore's is: the
  /// test adds snapshots and errors as they would arrive. Broadcast, so
  /// Riverpod's retry can listen again.
  StreamController<List<Destination>>? liveAll;

  /// The same, for the audio stops.
  StreamController<List<Segment>>? liveSegments;

  int allReads = 0;
  int segmentReads = 0;

  @override
  Stream<List<Destination>> watchAll({String? category}) {
    allReads++;
    if (liveAll case final live?) return live.stream;
    if (holdAll) return StreamController<List<Destination>>().stream;
    if (failAll) return Stream.error(error);
    return super.watchAll(category: category);
  }

  @override
  Stream<List<Segment>> watchSegments(String destinationId) {
    segmentReads++;
    if (liveSegments case final live?) return live.stream;
    if (failSegments) return Stream.error(error);
    return super.watchSegments(destinationId);
  }
}
