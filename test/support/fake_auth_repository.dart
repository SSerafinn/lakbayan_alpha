import "dart:async";

import "package:lakbayan/features/auth/domain/app_user.dart";
import "package:lakbayan/features/auth/domain/auth_repository.dart";

/// In-memory [AuthRepository] so widget tests can drive auth without a Firebase
/// binding. Lets a test hold the stream open to exercise the splash state.
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({AppUser? initialUser, this.emitInitial = true})
      : _current = initialUser {
    if (emitInitial) _controller.add(_current);
  }

  /// When false, the stream stays empty so the router sees a loading auth
  /// state — the cold-start case the splash screen exists for.
  final bool emitInitial;

  final _controller = StreamController<AppUser?>.broadcast();
  AppUser? _current;

  /// Set by tests to make the next call fail.
  AuthFailure? nextFailure;

  int signInCalls = 0;
  int signUpCalls = 0;
  int googleCalls = 0;
  int signOutCalls = 0;
  final resetEmails = <String>[];

  @override
  Stream<AppUser?> authStateChanges() async* {
    if (emitInitial) yield _current;
    yield* _controller.stream;
  }

  @override
  AppUser? get currentUser => _current;

  @override
  Future<AppUser> signInWithEmail({
    required String email,
    required String password,
  }) async {
    signInCalls++;
    return _complete(AppUser(uid: "uid-signin", email: email));
  }

  @override
  Future<AppUser> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    signUpCalls++;
    return _complete(AppUser(uid: "uid-signup", email: email));
  }

  @override
  Future<AppUser> signInWithGoogle() async {
    googleCalls++;
    return _complete(
      const AppUser(uid: "uid-google", email: "traveller@gmail.com"),
    );
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    if (nextFailure case final f?) {
      nextFailure = null;
      throw AuthException(f);
    }
    resetEmails.add(email);
  }

  @override
  Future<void> signOut() async {
    signOutCalls++;
    _current = null;
    _controller.add(null);
  }

  AppUser _complete(AppUser user) {
    if (nextFailure case final f?) {
      nextFailure = null;
      throw AuthException(f);
    }
    _current = user;
    _controller.add(user);
    return user;
  }

  void dispose() => _controller.close();
}
