import "package:cloud_firestore/cloud_firestore.dart";
import "package:firebase_auth/firebase_auth.dart" as fb;
import "package:riverpod_annotation/riverpod_annotation.dart";

import "../data/firebase_auth_repository.dart";
import "../data/user_profile_repository.dart";
import "app_user.dart";
import "auth_repository.dart";
import "user_profile.dart";

part "auth_providers.g.dart";

/// Overridden in tests and wherever Firebase is unavailable.
@Riverpod(keepAlive: true)
AuthRepository authRepository(Ref ref) =>
    FirebaseAuthRepository(fb.FirebaseAuth.instance);

@Riverpod(keepAlive: true)
UserProfileRepository userProfileRepository(Ref ref) =>
    UserProfileRepository(FirebaseFirestore.instance);

/// The current identity, or `null` when signed out.
///
/// Everything that cares about sign-in state watches this — including the
/// router's redirect.
@Riverpod(keepAlive: true)
Stream<AppUser?> authState(Ref ref) =>
    ref.watch(authRepositoryProvider).authStateChanges();

/// The signed-in user's Firestore profile, or `null` when signed out.
@riverpod
Stream<UserProfile?> userProfile(Ref ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream.value(null);
  return ref.watch(userProfileRepositoryProvider).watch(user.uid);
}

/// Whether the user chose "Skip for now — browse as guest".
///
/// This is **not** Firebase anonymous sign-in: that would mint a real account
/// and a `users/{uid}` document for someone who declined to sign up. It is
/// session-only, so a relaunch shows the auth screen again — which matches the
/// wireframe, where guest is an escape hatch rather than an account type.
@Riverpod(keepAlive: true)
class GuestMode extends _$GuestMode {
  @override
  bool build() => false;

  void enable() => state = true;
  void disable() => state = false;
}

/// Drives the sign-in screen.
///
/// Holds no user of its own — [authStateProvider] is the single source of truth
/// for who is signed in. This only tracks the in-flight request so the screen
/// can disable inputs and surface a failure.
@riverpod
class AuthController extends _$AuthController {
  @override
  FutureOr<void> build() {}

  Future<bool> signInWithEmail(String email, String password) =>
      _run((repo) => repo.signInWithEmail(email: email, password: password));

  Future<bool> signUpWithEmail(String email, String password) =>
      _run((repo) => repo.signUpWithEmail(email: email, password: password));

  Future<bool> signInWithGoogle() => _run((repo) => repo.signInWithGoogle());

  Future<bool> sendPasswordReset(String email) async {
    state = const AsyncLoading();
    try {
      await ref.read(authRepositoryProvider).sendPasswordResetEmail(email);
      state = const AsyncData(null);
      return true;
    } on AuthException catch (e, st) {
      state = AsyncError(e, st);
      return false;
    }
  }

  Future<void> signOut() async {
    state = const AsyncLoading();
    await ref.read(authRepositoryProvider).signOut();
    // Signing out is exactly the case where this provider goes away mid-call:
    // the auth stream emits null, the router redirects, and the screen holding
    // it is disposed — all before this line. Writing state then throws
    // "Cannot use the Ref ... after it has been disposed", which was showing
    // up in the console on every sign-in and sign-out.
    if (ref.mounted) state = const AsyncData(null);
  }

  /// Runs an auth call, then makes sure `users/{uid}` exists.
  ///
  /// A failure to write the profile is logged into state but does **not** undo
  /// the sign-in — the user is legitimately authenticated at that point, and
  /// signing them back out would be a worse outcome than a profile that gets
  /// created on their next launch.
  Future<bool> _run(Future<AppUser> Function(AuthRepository) action) async {
    state = const AsyncLoading();

    // Both repositories are read **before** the first await, not after it. A
    // successful sign-in disposes this provider on the way through — the auth
    // stream emits, the router redirects home, and the screen holding the
    // controller is gone — and `ref.read` past that point throws rather than
    // returning. Reading the profile repository after the gap is what put
    // "Cannot use the Ref ... after it has been disposed" in the console.
    final repository = ref.read(authRepositoryProvider);
    final profiles = ref.read(userProfileRepositoryProvider);

    try {
      final user = await action(repository);
      try {
        await profiles.ensureProfile(user);
      } catch (e, st) {
        if (ref.mounted) state = AsyncError(e, st);
        return true;
      }
      if (ref.mounted) state = const AsyncData(null);
      return true;
    } on AuthException catch (e, st) {
      // Guarded like the rest: a failure can arrive after the caller has gone,
      // and this one matters most — the screen that would show the error is
      // usually still there, but it must not throw when it is not.
      if (ref.mounted) state = AsyncError(e, st);
      return false;
    }
  }
}
