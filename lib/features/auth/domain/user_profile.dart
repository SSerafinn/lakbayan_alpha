import "package:freezed_annotation/freezed_annotation.dart";

import "../../../core/models/timestamp_converter.dart";

part "user_profile.freezed.dart";
part "user_profile.g.dart";

/// The `users/{uid}` document — part of the FE↔BE contract in
/// `docs/DATA_MODEL.md`. Field names mirror Firestore exactly.
///
/// There is deliberately **no `role` field**. Admin rights are a custom auth
/// claim (`request.auth.token.admin`), enforced in `firestore.rules`; a client
/// that writes `role` is rejected outright.
@freezed
abstract class UserProfile with _$UserProfile {
  const factory UserProfile({
    required String uid,
    String? email,
    String? displayName,
    String? photoUrl,

    /// Tour ids the user saved. Denormalized onto the user so the "Saved"
    /// screen is a single local-first read.
    @Default(<String>[]) List<String> savedTourIds,

    /// Towns whose offline bundle this user has downloaded.
    @Default(<String>[]) List<String> downloadedTownIds,
    @TimestampConverter() DateTime? createdAt,
    @TimestampConverter() DateTime? updatedAt,
  }) = _UserProfile;

  factory UserProfile.fromJson(Map<String, dynamic> json) =>
      _$UserProfileFromJson(json);
}

