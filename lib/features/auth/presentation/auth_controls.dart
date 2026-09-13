import "package:flutter/material.dart";

import "../../../core/theme/app_icons.dart";
import "../../../core/theme/app_dimens.dart";
import "../../../core/theme/app_typography.dart";
import "../../../core/theme/lakbayan_colors.dart";

/// Names a field, with room for one affordance on the same line. Above the
/// field rather than floating inside, so it survives the field having content.
class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {this.trailing, super.key});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Text(
            text,
            style: AppTypography.labelMedium.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        ?trailing,
      ],
    );
  }
}

/// Separates the form from the provider beneath it.
class OrDivider extends StatelessWidget {
  const OrDivider({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(child: Divider(color: scheme.outlineVariant)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.x3),
          child: Text(
            "OR",
            style: AppTypography.labelMedium.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(child: Divider(color: scheme.outlineVariant)),
      ],
    );
  }
}

class PrimaryAction extends StatelessWidget {
  const PrimaryAction({
    required this.label,
    required this.busy,
    required this.onPressed,
    super.key,
  });

  final String label;
  final bool busy;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, AppSize.formButton),
      ),
      child: busy
          ? SizedBox(
              width: AppSpace.x5,
              height: AppSpace.x5,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: scheme.onPrimary,
              ),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(label),
                const SizedBox(width: AppSpace.x2),
                const Icon(AppIcons.arrowForward, size: 18),
              ],
            ),
    );
  }
}

class ModeSwitch extends StatelessWidget {
  const ModeSwitch({required this.isSignUp, required this.onTap, super.key});

  final bool isSignUp;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          isSignUp ? "Already have an account?" : "New to Lakbayan?",
          style: AppTypography.bodyMedium.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        TextButton(
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.x2),
          ),
          onPressed: onTap,
          child: Text(isSignUp ? "Log in" : "Sign up"),
        ),
      ],
    );
  }
}

class ErrorNote extends StatelessWidget {
  const ErrorNote(this.message, {super.key});

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
        borderRadius: AppRadii.smAll,
      ),
      child: Text(
        message,
        style: AppTypography.bodyMedium.copyWith(color: c.badgeErrorText),
      ),
    );
  }
}

class ProviderRow extends StatelessWidget {
  const ProviderRow({required this.label, this.onTap, super.key});

  final String label;
  final VoidCallback? onTap;

  static const double _markSize = 22;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadii.mdAll,
        child: Container(
          height: AppSize.formButton,
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.x4),
          decoration: BoxDecoration(
            borderRadius: AppRadii.mdAll,
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                "assets/images/google-logo.webp",
                width: _markSize,
                height: _markSize,
                errorBuilder: (context, error, stackTrace) => Icon(
                  AppIcons.account,
                  size: _markSize,
                  color: Theme.of(context).colorScheme.onSurface
                      .withValues(alpha: 0.38),
                ),
              ),
              const SizedBox(width: AppSpace.x3),
              Flexible(
                child: Text(
                  label,
                  style: AppTypography.labelLarge,
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
