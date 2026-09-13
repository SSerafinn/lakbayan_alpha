import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";

import "../../../core/theme/app_icons.dart";
import "../../../core/router/app_router.dart";
import "../../../core/theme/app_dimens.dart";
import "../../../core/theme/app_typography.dart";
import "../domain/app_user.dart";
import "../domain/auth_providers.dart";
import "auth_chrome.dart";
import "auth_controls.dart";

/// Wireframe 1b - Auth. Login and sign-up share one screen; sign-up expands
/// one extra field inline. Google only, per docs/DECISIONS.md D-06.
///
/// An illustrated header with a sheet drawn up over it, picking the shoreline
/// up where the landing page hands off.
class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  bool _isSignUp = false;
  bool _obscure = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _toggleMode() {
    setState(() {
      _isSignUp = !_isSignUp;
      _formKey.currentState?.reset();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authControllerProvider);
    final busy = state.isLoading;

    // The controller reports failures through its error state; the screen
    // renders them inline rather than as a snackbar so the message sits with
    // the fields it refers to.
    final failure = state.error is AuthException
        ? (state.error! as AuthException).failure
        : null;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: AbsorbPointer(
        absorbing: busy,
        child: Stack(
          children: [
            const AuthHeader(),
            Column(
              children: [
                SizedBox(
                  height: shorelineBand(context) - AppSize.authCardOverlap,
                ),
                Expanded(
                  child: AuthSheet(
                    // Down always goes back to the landing pages, whichever
                    // way this screen was reached. Pushed over them — the
                    // first-launch path — popping returns to the page the user
                    // left. Reached as the root route, which is every
                    // returning visitor now that the introduction runs once
                    // per device, there is nothing to pop, so go to them
                    // instead; the router keeps /landing reachable while
                    // signed out whether or not they have been seen.
                    onDismiss: () => context.canPop()
                        ? context.pop()
                        : context.go(Routes.landing),
                    child: Form(
                      key: _formKey,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpace.x6,
                          AppSpace.x5,
                          AppSpace.x6,
                          AppSpace.x5,
                        ),
                        children: [
                          const AuthWordmark(),
                          const SizedBox(height: AppSpace.x2),
                          Text(
                            "Kasabay sa Paglakbay, \nLakbayin ang Probinsiya ng Cagayan",
                            textAlign: TextAlign.center,
                            style: AppTypography.bodyMedium.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: AppSpace.x4),

                          const FieldLabel("EMAIL"),
                          const SizedBox(height: AppSpace.x2),
                          TextFormField(
                            controller: _email,
                            keyboardType: TextInputType.emailAddress,
                            autocorrect: false,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              hintText: "you@example.com",
                            ),
                            validator: (v) {
                              final value = v?.trim() ?? "";
                              if (value.isEmpty) return "Enter your email.";
                              // Loose: Firebase is the real authority.
                              if (!value.contains("@") ||
                                  !value.contains(".")) {
                                return "That doesn't look like an email address.";
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: AppSpace.x3),

                          FieldLabel(
                            "PASSWORD",
                            trailing: _isSignUp
                                ? null
                                : TextButton(
                                    onPressed: busy ? null : _resetPassword,
                                    child: const Text("Forgot password?"),
                                  ),
                          ),
                          const SizedBox(height: AppSpace.x2),
                          TextFormField(
                            controller: _password,
                            obscureText: _obscure,
                            textInputAction: _isSignUp
                                ? TextInputAction.next
                                : TextInputAction.done,
                            decoration: InputDecoration(
                              hintText: "At least 8 characters",
                              suffixIcon: IconButton(
                                onPressed: () =>
                                    setState(() => _obscure = !_obscure),
                                icon: Icon(
                                  _obscure
                                      ? AppIcons.visibility
                                      : AppIcons.visibilityOff,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                                tooltip: _obscure
                                    ? "Show password"
                                    : "Hide password",
                              ),
                            ),
                            validator: (v) {
                              final value = v ?? "";
                              if (value.isEmpty) {
                                return "Enter your password.";
                              }
                              if (_isSignUp && value.length < 8) {
                                return "Use at least 8 characters.";
                              }
                              return null;
                            },
                          ),

                          if (_isSignUp) ...[
                            const SizedBox(height: AppSpace.x4),
                            const FieldLabel("CONFIRM PASSWORD"),
                            const SizedBox(height: AppSpace.x2),
                            TextFormField(
                              controller: _confirm,
                              obscureText: _obscure,
                              textInputAction: TextInputAction.done,
                              decoration: const InputDecoration(
                                hintText: "Type it once more",
                              ),
                              validator: (v) => v == _password.text
                                  ? null
                                  : "Passwords don't match.",
                            ),
                          ],

                          if (failure != null) ...[
                            const SizedBox(height: AppSpace.x4),
                            ErrorNote(failure.message),
                          ],

                          const SizedBox(height: AppSpace.x4),
                          PrimaryAction(
                            label: _isSignUp ? "Create account" : "Log in",
                            busy: busy,
                            onPressed: busy ? null : _submit,
                          ),
                          const SizedBox(height: AppSpace.x1),
                          ModeSwitch(
                            isSignUp: _isSignUp,
                            onTap: busy ? null : _toggleMode,
                          ),

                          const SizedBox(height: AppSpace.x3),
                          const OrDivider(),
                          const SizedBox(height: AppSpace.x3),
                          ProviderRow(
                            label: "Continue with Google",
                            onTap: busy
                                ? null
                                : () => ref
                                      .read(authControllerProvider.notifier)
                                      .signInWithGoogle(),
                          ),

                          const SizedBox(height: AppSpace.x3),
                          Center(
                            child: TextButton(
                              onPressed: busy
                                  ? null
                                  : () => _continueAsGuest(context),
                              child: Text(
                                "BROWSE AS GUEST",
                                style: AppTypography.labelMedium.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final controller = ref.read(authControllerProvider.notifier);
    if (_isSignUp) {
      await controller.signUpWithEmail(_email.text, _password.text);
    } else {
      await controller.signInWithEmail(_email.text, _password.text);
    }
  }

  Future<void> _resetPassword() async {
    final email = _email.text.trim();
    if (email.isEmpty || !email.contains("@")) {
      _formKey.currentState?.validate();
      return;
    }
    final sent = await ref
        .read(authControllerProvider.notifier)
        .sendPasswordReset(email);
    if (sent && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Password reset sent to $email.")));
    }
  }

  void _continueAsGuest(BuildContext context) {
    ref.read(guestModeProvider.notifier).enable();
  }
}
