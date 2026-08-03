import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../../core/theme/app_colors.dart";
import "../../../core/theme/app_dimens.dart";
import "../../../core/theme/app_typography.dart";
import "../../../core/theme/lakbayan_colors.dart";
import "../domain/app_user.dart";
import "../domain/auth_providers.dart";

/// Wireframe 1b · Auth.
///
/// One screen carries both login and sign-up — the wireframe is explicit that
/// they share the fields and that "Sign-up" expands an extra field inline,
/// rather than pushing a second route.
///
/// Only Google appears under the divider. The wireframe also draws Facebook and
/// Twitter; `docs/DECISIONS.md` D-06 puts those out of v1 scope.
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

  @override
  Widget build(BuildContext context) {
    final c = context.lakbayan;
    final state = ref.watch(authControllerProvider);
    final busy = state.isLoading;

    // The controller reports failures through its error state; the screen
    // renders them inline rather than as a snackbar so the message sits with
    // the fields it refers to.
    final failure = state.error is AuthException
        ? (state.error! as AuthException).failure
        : null;

    return Scaffold(
      body: SafeArea(
        child: AbsorbPointer(
          absorbing: busy,
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpace.x6,
                vertical: AppSpace.x4,
              ),
              children: [
                const SizedBox(height: AppSpace.x5),
                Center(
                  child: Container(
                    width: 96,
                    height: 96,
                    decoration: const BoxDecoration(
                      color: AppColors.green500,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      "L",
                      style: AppTypography.display
                          .copyWith(color: Colors.white, fontSize: 44),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpace.x6),
                Text(
                  _isSignUp ? "Create your account" : "Welcome back",
                  style: AppTypography.h2,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpace.x6),

                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: "Email"),
                  validator: (v) {
                    final value = v?.trim() ?? "";
                    if (value.isEmpty) return "Enter your email.";
                    // Deliberately loose. Firebase is the real authority on
                    // whether an address is valid; this only catches typos.
                    if (!value.contains("@") || !value.contains(".")) {
                      return "That doesn't look like an email address.";
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpace.x3),

                TextFormField(
                  controller: _password,
                  obscureText: _obscure,
                  textInputAction:
                      _isSignUp ? TextInputAction.next : TextInputAction.done,
                  decoration: InputDecoration(
                    labelText: "Password",
                    suffixIcon: TextButton(
                      onPressed: () => setState(() => _obscure = !_obscure),
                      child: Text(_obscure ? "show" : "hide"),
                    ),
                  ),
                  validator: (v) {
                    final value = v ?? "";
                    if (value.isEmpty) return "Enter your password.";
                    // Only enforced on sign-up — an existing account may
                    // predate this rule and must still be able to log in.
                    if (_isSignUp && value.length < 8) {
                      return "Use at least 8 characters.";
                    }
                    return null;
                  },
                ),

                if (_isSignUp) ...[
                  const SizedBox(height: AppSpace.x3),
                  TextFormField(
                    controller: _confirm,
                    obscureText: _obscure,
                    textInputAction: TextInputAction.done,
                    decoration:
                        const InputDecoration(labelText: "Confirm password"),
                    validator: (v) =>
                        v == _password.text ? null : "Passwords don't match.",
                  ),
                ],

                if (!_isSignUp)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: busy ? null : _resetPassword,
                      child: const Text("Forgot password?"),
                    ),
                  ),

                if (failure != null) ...[
                  const SizedBox(height: AppSpace.x3),
                  _ErrorNote(failure.message),
                ],

                const SizedBox(height: AppSpace.x4),
                FilledButton(
                  onPressed: busy ? null : _submit,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 52),
                    shape: const RoundedRectangleBorder(
                      borderRadius: AppRadius.lgAll,
                    ),
                  ),
                  child: busy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(_isSignUp ? "Create account" : "Login"),
                ),
                const SizedBox(height: AppSpace.x3),
                OutlinedButton(
                  onPressed: busy
                      ? null
                      : () => setState(() {
                            _isSignUp = !_isSignUp;
                            _formKey.currentState?.reset();
                          }),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 52),
                    shape: const RoundedRectangleBorder(
                      borderRadius: AppRadius.lgAll,
                    ),
                  ),
                  child: Text(_isSignUp ? "I already have an account" : "Sign-up"),
                ),

                const SizedBox(height: AppSpace.x5),
                Row(
                  children: [
                    Expanded(child: Divider(color: c.line)),
                    Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: AppSpace.x3),
                      child: Text("or", style: AppTypography.caption),
                    ),
                    Expanded(child: Divider(color: c.line)),
                  ],
                ),
                const SizedBox(height: AppSpace.x4),

                _ProviderRow(
                  label: "Continue with Google",
                  onTap: busy
                      ? null
                      : () => ref
                          .read(authControllerProvider.notifier)
                          .signInWithGoogle(),
                ),

                const SizedBox(height: AppSpace.x5),
                Center(
                  child: TextButton(
                    onPressed: busy ? null : () => _continueAsGuest(context),
                    child: Text(
                      "Skip for now — browse as guest",
                      style: AppTypography.caption
                          .copyWith(color: c.textSecondary),
                    ),
                  ),
                ),
              ],
            ),
          ),
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
    // Navigation is the router's job — it redirects on auth state change.
  }

  Future<void> _resetPassword() async {
    final email = _email.text.trim();
    if (email.isEmpty || !email.contains("@")) {
      // Reuse the field validator's message rather than inventing a second one.
      _formKey.currentState?.validate();
      return;
    }
    final sent =
        await ref.read(authControllerProvider.notifier).sendPasswordReset(email);
    if (sent && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Password reset sent to $email.")),
      );
    }
  }

  void _continueAsGuest(BuildContext context) {
    // Guest browsing is a wireframe requirement: discovery stays open and only
    // saving prompts auth. Tracked in session state, not in Firebase — this is
    // NOT anonymous sign-in, which would create a real account.
    ref.read(guestModeProvider.notifier).enable();
  }
}

/// Inline field error. The wireframe keeps errors red-free and sits them under
/// the fields; this uses the error colour but stays in the soft badge idiom
/// rather than shouting.
class _ErrorNote extends StatelessWidget {
  const _ErrorNote(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    final c = context.lakbayan;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.x4,
        vertical: AppSpace.x3,
      ),
      decoration: BoxDecoration(
        color: c.badgeErrorFill,
        borderRadius: AppRadius.mdAll,
      ),
      child: Text(
        message,
        style: AppTypography.body.copyWith(color: c.badgeErrorText),
      ),
    );
  }
}

/// A social provider row — 48dp tall to meet the touch target minimum.
class _ProviderRow extends StatelessWidget {
  const _ProviderRow({required this.label, this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.lakbayan;
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.mdAll,
        child: Container(
          height: AppSize.minTouchTarget,
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.x4),
          decoration: BoxDecoration(
            borderRadius: AppRadius.mdAll,
            border: Border.all(color: c.line),
          ),
          child: Row(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: c.textDisabled, width: 1.5),
                ),
              ),
              const SizedBox(width: AppSpace.x3),
              // Flexible, not a bare Text: at 360dp the label is 2px wider
              // than the row and overflows. Ellipsis is preferable to a
              // clipped, striped error box on a narrow phone.
              Flexible(
                child: Text(
                  label,
                  style: AppTypography.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
