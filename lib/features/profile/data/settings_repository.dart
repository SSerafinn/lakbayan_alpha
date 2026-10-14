import "package:cloud_firestore/cloud_firestore.dart";
import "package:flutter/foundation.dart";

import "../../../core/models/app_settings.dart";

/// Reads the province's `settings/app` and `settings/policies`, written in the
/// CMS's Settings. Public: a guest reads them too.
///
/// Firestore's offline persistence serves the last copy it saw. What it
/// cannot serve is a document this phone has never read, and that is a
/// different thing from a document nobody has written: [SettingsNotYetLoaded]
/// says which, so a screen can tell someone offline to connect once rather
/// than tell them the province has published nothing.
class SettingsRepository {
  const SettingsRepository(this._firestore);

  final FirebaseFirestore _firestore;

  /// Contact, emergency lines and the Explore notice. Null until the CMS has
  /// saved them.
  Stream<AppSettings?> watchApp() => _watch("app", AppSettings.fromJson);

  /// The privacy policy and terms. Null until the CMS has saved them.
  Stream<PolicySettings?> watchPolicies() =>
      _watch("policies", PolicySettings.fromJson);

  Stream<T?> _watch<T>(
    String id,
    T Function(Map<String, dynamic> json) fromJson,
  ) => _firestore.collection("settings").doc(id).snapshots().map((snap) {
    final data = snap.data();
    if (data == null) {
      if (snap.metadata.isFromCache) throw const SettingsNotYetLoaded();
      return null;
    }
    try {
      return fromJson(data);
    } catch (e) {
      // A malformed document reads as an unwritten one rather than taking a
      // screen down with it.
      debugPrint("Ignoring malformed settings/$id: $e");
      return null;
    }
  });
}

/// The phone is offline and has never read this document. Not "empty": the
/// province may well have written it.
class SettingsNotYetLoaded implements Exception {
  const SettingsNotYetLoaded();

  @override
  String toString() => "Not loaded yet. Connect to the internet once.";
}
