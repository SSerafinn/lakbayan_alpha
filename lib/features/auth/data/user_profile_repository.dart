import "package:cloud_firestore/cloud_firestore.dart";

import "../domain/app_user.dart";
import "../domain/user_profile.dart";

/// Reads and writes `users/{uid}`.
///
/// Reads are local-first: Firestore's offline persistence serves the cached
/// document when there is no connection, which is what keeps the profile screen
/// working on a boat off Palaui.
class UserProfileRepository {
  UserProfileRepository(this._firestore);

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> _doc(String uid) =>
      _firestore.collection("users").doc(uid);

  Stream<UserProfile?> watch(String uid) => _doc(uid).snapshots().map(
    (snap) => snap.exists ? UserProfile.fromJson(_withId(snap)) : null,
  );

  Future<UserProfile?> read(String uid) async {
    final snap = await _doc(uid).get();
    return snap.exists ? UserProfile.fromJson(_withId(snap)) : null;
  }

  /// Creates the profile on first sign-in, or refreshes the identity fields on
  /// subsequent ones.
  ///
  /// Uses two distinct paths rather than a blind `set(merge: true)` because
  /// `firestore.rules` treats create and update differently, and because
  /// `createdAt` must not be rewritten on every login.
  Future<void> ensureProfile(AppUser user) async {
    final ref = _doc(user.uid);
    final snap = await ref.get();

    final identity = <String, Object?>{
      "uid": user.uid,
      "email": user.email,
      "displayName": user.displayName,
      "photoUrl": user.photoUrl,
      "updatedAt": FieldValue.serverTimestamp(),
    };

    if (snap.exists) {
      await ref.update(identity);
      return;
    }

    await ref.set({
      ...identity,
      "savedTourIds": <String>[],
      "downloadedTownIds": <String>[],
      "createdAt": FieldValue.serverTimestamp(),
    });
  }

  Map<String, dynamic> _withId(DocumentSnapshot<Map<String, dynamic>> snap) => {
    ...?snap.data(),
    "uid": snap.id,
  };
}
