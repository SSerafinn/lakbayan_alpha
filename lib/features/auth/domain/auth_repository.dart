import "app_user.dart";

/// Auth operations the app needs, stated without reference to Firebase.
///
/// Keeping this abstract is what lets widget tests drive sign-in without a
/// Firebase binding, and leaves room to swap providers later without touching
/// the presentation layer.
///
/// Every method throws [AuthException] on failure — never a raw
/// `FirebaseAuthException`.
abstract interface class AuthRepository {
  /// Emits on every auth state change, starting with the current state.
  /// `null` means signed out.
  Stream<AppUser?> authStateChanges();

  AppUser? get currentUser;

  Future<AppUser> signInWithEmail({
    required String email,
    required String password,
  });

  Future<AppUser> signUpWithEmail({
    required String email,
    required String password,
  });

  /// v1 social provider. See `docs/DECISIONS.md` D-06 — Facebook and Twitter
  /// appear in the wireframes but are explicitly out of scope.
  Future<AppUser> signInWithGoogle();

  Future<void> sendPasswordResetEmail(String email);

  Future<void> signOut();
}
