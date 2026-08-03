import "package:flutter/foundation.dart";

/// The signed-in identity, as far as the app is concerned.
///
/// A deliberately thin read model over Firebase's `User` so that widgets and
/// providers never import `firebase_auth`. Nothing here is persisted — the
/// Firestore side of a user lives in `UserProfile`.
@immutable
class AppUser {
  const AppUser({
    required this.uid,
    this.email,
    this.displayName,
    this.photoUrl,
    this.isAnonymous = false,
  });

  final String uid;
  final String? email;
  final String? displayName;
  final String? photoUrl;
  final bool isAnonymous;

  /// What to show in the UI when we have no display name — the local part of
  /// the email reads better than a raw uid.
  String get label {
    if (displayName case final n? when n.trim().isNotEmpty) return n;
    if (email case final e? when e.contains("@")) return e.split("@").first;
    return "Traveller";
  }

  @override
  bool operator ==(Object other) =>
      other is AppUser &&
      other.uid == uid &&
      other.email == email &&
      other.displayName == displayName &&
      other.photoUrl == photoUrl &&
      other.isAnonymous == isAnonymous;

  @override
  int get hashCode =>
      Object.hash(uid, email, displayName, photoUrl, isAnonymous);
}

/// Why an auth attempt failed, in terms the UI can render.
///
/// Firebase error codes are mapped to these at the repository boundary so no
/// screen has to know strings like `wrong-password`, and so the messages stay
/// consistent between sign-in and sign-up.
enum AuthFailure {
  invalidCredentials,
  emailAlreadyInUse,
  weakPassword,
  invalidEmail,
  userDisabled,
  tooManyRequests,
  networkUnavailable,
  cancelled,
  unknown;

  /// Deliberately vague for [invalidCredentials]: saying which of the email or
  /// the password was wrong tells an attacker which accounts exist.
  String get message => switch (this) {
        invalidCredentials => "That email and password don't match.",
        emailAlreadyInUse => "That email already has an account. Try logging in.",
        weakPassword => "Use at least 8 characters.",
        invalidEmail => "That doesn't look like an email address.",
        userDisabled => "This account has been disabled.",
        tooManyRequests => "Too many attempts. Wait a moment and try again.",
        networkUnavailable => "You're offline. Connect and try again.",
        cancelled => "Sign-in was cancelled.",
        unknown => "Something went wrong. Try again.",
      };
}

/// Thrown by [AuthRepository]; carries a [AuthFailure] the UI can render.
class AuthException implements Exception {
  const AuthException(this.failure);

  final AuthFailure failure;

  String get message => failure.message;

  @override
  String toString() => "AuthException(${failure.name})";
}
