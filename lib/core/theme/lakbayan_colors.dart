import "package:flutter/material.dart";

import "app_colors.dart";

/// Brand tokens that Material's [ColorScheme] has no slot for.
///
/// Gold is the clearest example: it is an accent for AR and Featured badges, and
/// deliberately *never* a button, so mapping it onto `ColorScheme.tertiary`
/// would invite Material to use it as an action colour. Keeping it here makes
/// the design system's "gold is never a button" rule structural rather than a
/// convention people have to remember.
///
/// Access with `Theme.of(context).extension<LakbayanColors>()!`, or the
/// `context.lakbayan` getter below.
@immutable
class LakbayanColors extends ThemeExtension<LakbayanColors> {
  const LakbayanColors({
    required this.gold,
    required this.goldText,
    required this.goldContainer,
    required this.greenTint,
    required this.greenSubtle,
    required this.blueTint,
    required this.blueSubtle,
    required this.line,
    required this.textSecondary,
    required this.textDisabled,
    required this.textOnLightGreen,
    required this.badgeNeutralFill,
    required this.badgeNeutralText,
    required this.badgeErrorFill,
    required this.badgeErrorText,
  });

  /// Accent fills — AR and Featured badges only.
  final Color gold;

  /// Gold *text* on a light background. Steps down to gold/700 for AA.
  final Color goldText;
  final Color goldContainer;

  /// green/100 — selected chips, section fills.
  final Color greenTint;

  /// green/50 — subtle backgrounds, selected list rows.
  final Color greenSubtle;
  final Color blueTint;
  final Color blueSubtle;

  final Color line;
  final Color textSecondary;
  final Color textDisabled;

  /// Green text on white must be /700 or /900 — never the /500 base.
  final Color textOnLightGreen;

  final Color badgeNeutralFill;
  final Color badgeNeutralText;
  final Color badgeErrorFill;
  final Color badgeErrorText;

  static const light = LakbayanColors(
    gold: AppColors.gold500,
    goldText: AppColors.gold700,
    goldContainer: AppColors.gold100,
    greenTint: AppColors.green100,
    greenSubtle: AppColors.green50,
    blueTint: AppColors.blue100,
    blueSubtle: AppColors.blue50,
    line: AppColors.line,
    textSecondary: AppColors.slate500,
    textDisabled: AppColors.slate300,
    textOnLightGreen: AppColors.green700,
    badgeNeutralFill: AppColors.green100,
    badgeNeutralText: AppColors.green700,
    badgeErrorFill: AppColors.errorContainer,
    badgeErrorText: AppColors.onErrorContainer,
  );

  /// Dark mode is v2 scope in the design system; these follow its stated rule
  /// that interactive colour steps to the /300 tints on dark surfaces.
  static const dark = LakbayanColors(
    gold: AppColors.gold300,
    goldText: AppColors.gold300,
    goldContainer: Color(0xFF3D2E08),
    greenTint: Color(0xFF1A3D28),
    greenSubtle: Color(0xFF163322),
    blueTint: Color(0xFF163A52),
    blueSubtle: Color(0xFF12283D),
    line: Color(0xFF24402F),
    textSecondary: Color(0xFFA8BCB0),
    textDisabled: Color(0xFF6F8578),
    textOnLightGreen: AppColors.green300,
    badgeNeutralFill: Color(0xFF1A3D28),
    badgeNeutralText: AppColors.green300,
    badgeErrorFill: Color(0xFF4A1F1F),
    badgeErrorText: Color(0xFFF0A5A5),
  );

  @override
  LakbayanColors copyWith({
    Color? gold,
    Color? goldText,
    Color? goldContainer,
    Color? greenTint,
    Color? greenSubtle,
    Color? blueTint,
    Color? blueSubtle,
    Color? line,
    Color? textSecondary,
    Color? textDisabled,
    Color? textOnLightGreen,
    Color? badgeNeutralFill,
    Color? badgeNeutralText,
    Color? badgeErrorFill,
    Color? badgeErrorText,
  }) => LakbayanColors(
    gold: gold ?? this.gold,
    goldText: goldText ?? this.goldText,
    goldContainer: goldContainer ?? this.goldContainer,
    greenTint: greenTint ?? this.greenTint,
    greenSubtle: greenSubtle ?? this.greenSubtle,
    blueTint: blueTint ?? this.blueTint,
    blueSubtle: blueSubtle ?? this.blueSubtle,
    line: line ?? this.line,
    textSecondary: textSecondary ?? this.textSecondary,
    textDisabled: textDisabled ?? this.textDisabled,
    textOnLightGreen: textOnLightGreen ?? this.textOnLightGreen,
    badgeNeutralFill: badgeNeutralFill ?? this.badgeNeutralFill,
    badgeNeutralText: badgeNeutralText ?? this.badgeNeutralText,
    badgeErrorFill: badgeErrorFill ?? this.badgeErrorFill,
    badgeErrorText: badgeErrorText ?? this.badgeErrorText,
  );

  @override
  LakbayanColors lerp(covariant LakbayanColors? other, double t) {
    if (other == null) return this;
    return LakbayanColors(
      gold: Color.lerp(gold, other.gold, t)!,
      goldText: Color.lerp(goldText, other.goldText, t)!,
      goldContainer: Color.lerp(goldContainer, other.goldContainer, t)!,
      greenTint: Color.lerp(greenTint, other.greenTint, t)!,
      greenSubtle: Color.lerp(greenSubtle, other.greenSubtle, t)!,
      blueTint: Color.lerp(blueTint, other.blueTint, t)!,
      blueSubtle: Color.lerp(blueSubtle, other.blueSubtle, t)!,
      line: Color.lerp(line, other.line, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textDisabled: Color.lerp(textDisabled, other.textDisabled, t)!,
      textOnLightGreen: Color.lerp(
        textOnLightGreen,
        other.textOnLightGreen,
        t,
      )!,
      badgeNeutralFill: Color.lerp(
        badgeNeutralFill,
        other.badgeNeutralFill,
        t,
      )!,
      badgeNeutralText: Color.lerp(
        badgeNeutralText,
        other.badgeNeutralText,
        t,
      )!,
      badgeErrorFill: Color.lerp(badgeErrorFill, other.badgeErrorFill, t)!,
      badgeErrorText: Color.lerp(badgeErrorText, other.badgeErrorText, t)!,
    );
  }
}

extension LakbayanThemeX on BuildContext {
  /// Brand tokens outside Material's [ColorScheme].
  LakbayanColors get lakbayan => Theme.of(this).extension<LakbayanColors>()!;
}
