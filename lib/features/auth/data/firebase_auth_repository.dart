import "package:firebase_auth/firebase_auth.dart" as fb;
import "package:flutter/foundation.dart";
import "package:google_sign_in/google_sign_in.dart";

import "../../../core/config/app_config.dart";
import "../domain/app_user.dart";
import "../domain/auth_repository.dart";

/// [AuthRepository] backed by Firebase Auth.
///
/// The whole point of this class is to be the only place that knows Firebase
/// error codes exist. Everything above it sees [AppUser] and [AuthException].
class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository(this._auth);

  final fb.FirebaseAuth _auth;

  @override
  Stream<AppUser?> authStateChanges() =>
      _auth.authStateChanges().map(_toAppUser);

  @override
  AppUser? get currentUser => _toAppUser(_auth.currentUser);

  @override
  Future<AppUser> signInWithEmail({
    required String email,
    required String password,
  }) => _guard(() async {
    final cred = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    return _requireUser(cred.user);
  });

  @override
  Future<AppUser> signUpWithEmail({
    required String email,
    required String password,
  }) => _guard(() async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    return _requireUser(cred.user);
  });

  /// NOTE: this path cannot be exercised against the Auth emulator. Obtaining a
  /// Google ID token requires real Google infrastructure plus a Firebase
  /// project with this app's SHA-1 registered. Until `flutterfire configure`
  /// has been run, expect [AuthFailure.unknown] here.
  @override
  Future<AppUser> signInWithGoogle() => _guard(() async {
    final google = GoogleSignIn.instance;

    // Web needs the OAuth client ID handed to it; Android reads it from
    // google-services.json and rejects an explicit one. Passing it
    // unconditionally breaks Android, so branch on the platform.
    if (kIsWeb) {
      if (AppConfig.googleWebClientId.isEmpty) {
        throw const AuthException(AuthFailure.googleWebNotConfigured);
      }
      await google.initialize(clientId: AppConfig.googleWebClientId);
    } else {
      await google.initialize();
    }

    final GoogleSignInAccount account;
    try {
      account = await google.authenticate();
    } on GoogleSignInException catch (e) {
      throw AuthException(
        e.code == GoogleSignInExceptionCode.canceled
            ? AuthFailure.cancelled
            : AuthFailure.unknown,
      );
    }

    final idToken = account.authentication.idToken;
    if (idToken == null) throw const AuthException(AuthFailure.unknown);

    final cred = await _auth.signInWithCredential(
      fb.GoogleAuthProvider.credential(idToken: idToken),
    );
    return _requireUser(cred.user);
  });

  @override
  Future<void> sendPasswordResetEmail(String email) =>
      _guard(() => _auth.sendPasswordResetEmail(email: email.trim()));

  @override
  Future<void> signOut() async {
    // Sign out of Google too, or the next sign-in silently reuses the account
    // and the user cannot switch identities.
    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {
      // Never configured or never used — not a reason to block sign-out.
    }
    await _auth.signOut();
  }

  AppUser? _toAppUser(fb.User? user) => user == null
      ? null
      : AppUser(
          uid: user.uid,
          email: user.email,
          displayName: user.displayName,
          photoUrl: user.photoURL,
          isAnonymous: user.isAnonymous,
        );

  AppUser _requireUser(fb.User? user) {
    final mapped = _toAppUser(user);
    if (mapped == null) throw const AuthException(AuthFailure.unknown);
    return mapped;
  }

  /// Runs [action], translating Firebase failures into [AuthException].
  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on AuthException {
      rethrow;
    } on fb.FirebaseAuthException catch (e) {
      debugPrint("FirebaseAuthException(${e.code}): ${e.message}");
      throw AuthException(_mapCode(e.code));
    } catch (e, st) {
      debugPrintStack(label: "Unexpected auth error: $e", stackTrace: st);
      throw const AuthException(AuthFailure.unknown);
    }
  }

  AuthFailure _mapCode(String code) => switch (code) {
    // Modern Firebase collapses wrong-password and user-not-found into
    // invalid-credential precisely to avoid leaking account existence.
    // The older codes are still emitted by some SDK versions.
    "invalid-credential" ||
    "wrong-password" ||
    "user-not-found" => AuthFailure.invalidCredentials,
    "email-already-in-use" => AuthFailure.emailAlreadyInUse,
    "weak-password" => AuthFailure.weakPassword,
    "invalid-email" => AuthFailure.invalidEmail,
    "user-disabled" => AuthFailure.userDisabled,
    "too-many-requests" => AuthFailure.tooManyRequests,
    "network-request-failed" => AuthFailure.networkUnavailable,
    _ => AuthFailure.unknown,
  };
}
