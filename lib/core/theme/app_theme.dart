import "package:flutter/material.dart";

import "app_colors.dart";
import "app_dimens.dart";
import "app_typography.dart";
import "lakbayan_colors.dart";

/// The Lakbayan Material 3 theme, built from the design system tokens.
///
/// Component themes are configured here rather than at call sites so that a
/// stock `FilledButton` or `Chip` already matches the specimen. The design
/// system's rules are encoded structurally where possible:
///
/// - Primary action = green/500 fill. Secondary = blue/500 outline.
/// - Gold is an accent for badges only and is intentionally NOT wired to any
///   button or action role — it lives in [LakbayanColors].
/// - Corners are 12–16dp. Buttons take 16dp; the pill is reserved for
///   chips, per the 2026-08 rebrand.
ThemeData buildAppTheme() => _build(Brightness.light);

ThemeData buildAppDarkTheme() => _build(Brightness.dark);

ThemeData _build(Brightness brightness) {
  final isDark = brightness == Brightness.dark;

  final scheme = isDark
      ? const ColorScheme.dark(
          primary: AppColors.green300,
          onPrimary: AppColors.green900,
          primaryContainer: Color(0xFF1A3D28),
          onPrimaryContainer: AppColors.green300,
          secondary: AppColors.blue300,
          onSecondary: AppColors.green900,
          surface: AppColors.darkSurface,
          onSurface: AppColors.darkText,
          error: AppColors.error,
          onError: Colors.white,
        )
      : const ColorScheme.light(
          primary: AppColors.green500,
          onPrimary: Colors.white,
          primaryContainer: AppColors.green100,
          onPrimaryContainer: AppColors.green700,
          secondary: AppColors.blue500,
          onSecondary: Colors.white,
          secondaryContainer: AppColors.blue100,
          onSecondaryContainer: AppColors.blue700,
          surface: AppColors.surface,
          onSurface: AppColors.ink900,
          outline: AppColors.line,
          error: AppColors.error,
          onError: Colors.white,
        );

  final textTheme = isDark
      ? AppTypography.darkTextTheme()
      : AppTypography.textTheme();
  final brand = isDark ? LakbayanColors.dark : LakbayanColors.light;

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    textTheme: textTheme,
    scaffoldBackgroundColor: isDark
        ? AppColors.darkBackground
        : AppColors.background,
    fontFamily: AppTypography.bodyFamily,
    extensions: [brand],

    // 56dp. White over scrolling content is the default; detail screens opt
    // into the green bar explicitly.
    appBarTheme: AppBarTheme(
      toolbarHeight: AppSize.appBarHeight,
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.surface,
      foregroundColor: isDark ? AppColors.darkText : AppColors.ink900,
      titleTextStyle: textTheme.titleLarge,
      surfaceTintColor: Colors.transparent,
    ),

    // Primary — green fill, 48dp tall to meet the touch target minimum.
    // 16dp corners rather than a pill since the 2026-08 rebrand: a pill at
    // full width reads as a tag, and the softer rectangle sits better with
    // the field shape above it.
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        disabledBackgroundColor: AppColors.disabledFill,
        disabledForegroundColor: AppColors.slate300,
        minimumSize: const Size(0, AppSize.minTouchTarget),
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.x4),
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.lgAll),
        textStyle: AppTypography.label,
      ),
    ),

    // Secondary — blue outline, never a filled blue button.
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: scheme.secondary,
        side: BorderSide(color: scheme.secondary, width: 1.5),
        minimumSize: const Size(0, AppSize.minTouchTarget),
        padding: const EdgeInsets.symmetric(horizontal: 22),
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.lgAll),
        textStyle: AppTypography.label,
      ),
    ),

    // Tertiary / "Skip" — green text, no chrome.
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: brand.textOnLightGreen,
        minimumSize: const Size(0, AppSize.minTouchTarget),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.pillAll),
        textStyle: AppTypography.label,
      ),
    ),

    cardTheme: CardThemeData(
      color: scheme.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.lgAll,
        side: BorderSide(color: brand.line),
      ),
    ),

    // Filter chips: selected = green/100 on a green/500 hairline.
    chipTheme: ChipThemeData(
      backgroundColor: scheme.surface,
      selectedColor: brand.greenTint,
      side: BorderSide(color: brand.line),
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.pillAll),
      labelStyle: AppTypography.label.copyWith(fontSize: 13),
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.x4),
      showCheckmark: false,
    ),

    dividerTheme: DividerThemeData(color: brand.line, thickness: 1, space: 1),

    navigationBarTheme: NavigationBarThemeData(
      height: AppSize.bottomNav,
      backgroundColor: scheme.surface,
      indicatorColor: brand.greenSubtle,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => AppTypography.caption.copyWith(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          fontVariations: const [FontVariation("wght", 600)],
          letterSpacing: 0.3,
          color: states.contains(WidgetState.selected)
              ? brand.textOnLightGreen
              : brand.textSecondary,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          size: 22,
          color: states.contains(WidgetState.selected)
              ? scheme.primary
              : brand.textDisabled,
        ),
      ),
    ),

    // Soft-filled fields with no resting outline. A boxed field on a white
    // sheet reads as a form to be processed; a filled one reads as a place to
    // write. The border appears only on focus, so the ring is information
    // rather than decoration.
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: isDark ? AppColors.darkSurface : AppColors.background,
      // Comfortable without being tall: a field this size still clears the
      // touch target with the text vertically centred in it.
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpace.x4,
        vertical: AppSpace.x4,
      ),
      isDense: true,
      border: const OutlineInputBorder(
        borderRadius: AppRadius.lgAll,
        borderSide: BorderSide.none,
      ),
      enabledBorder: const OutlineInputBorder(
        borderRadius: AppRadius.lgAll,
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: AppRadius.lgAll,
        borderSide: BorderSide(color: scheme.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: AppRadius.lgAll,
        borderSide: BorderSide(color: scheme.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: AppRadius.lgAll,
        borderSide: BorderSide(color: scheme.error, width: 1.5),
      ),
      labelStyle: AppTypography.body.copyWith(color: brand.textSecondary),
      floatingLabelStyle: AppTypography.caption.copyWith(
        color: scheme.primary,
        letterSpacing: 0.6,
      ),
      hintStyle: AppTypography.body.copyWith(color: brand.textDisabled),
    ),

    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
    ),

    listTileTheme: ListTileThemeData(
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpace.x1),
      titleTextStyle: AppTypography.title,
      subtitleTextStyle: AppTypography.body.copyWith(
        color: brand.textSecondary,
      ),
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
      minVerticalPadding: AppSpace.x3,
    ),
  );
}
