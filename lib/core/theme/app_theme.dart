import "package:flutter/material.dart";

import "../widgets/motion/page_transitions.dart";
import "app_colors.dart";
import "app_dimens.dart";
import "app_typography.dart";
import "lakbayan_colors.dart";

/// The Lakbayan Material 3 theme.
///
/// The page is paper (`surface`); a card is one step brighter
/// (`surfaceContainerLowest`), and what sits inside a card takes the paper
/// again (`surfaceContainerLow`). Component themes live here so stock widgets
/// carry the design without per-call-site overrides. See
/// `docs/DESIGN_SYSTEM.md`.
ThemeData buildAppTheme() => _build(Brightness.light);

ThemeData buildAppDarkTheme() => _build(Brightness.dark);

ThemeData _build(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  final scheme = isDark ? _darkScheme : _lightScheme;
  final brand = isDark ? LakbayanColors.dark : LakbayanColors.light;
  final card = scheme.surfaceContainerLowest;

  // The ramp carries no colour of its own; onSurface is applied here once.
  final textTheme = AppTypography.textTheme().apply(
    bodyColor: scheme.onSurface,
    displayColor: scheme.onSurface,
  );

  // Text buttons and links: the darker emerald, so words hold AA on paper.
  final linkColor = brand.textOnLightGreen;

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    textTheme: textTheme,
    scaffoldBackgroundColor: scheme.surface,
    canvasColor: scheme.surface,
    fontFamily: AppTypography.family,
    extensions: [brand],
    visualDensity: VisualDensity.standard,
    materialTapTargetSize: MaterialTapTargetSize.padded,
    // Press feedback is the control itself (`Pressable`: a spring shrink on
    // cards, tiles and buttons), not ink spreading from the finger. Rows keep
    // a flat highlight, the iOS list press.
    splashFactory: NoSplash.splashFactory,
    highlightColor: scheme.onSurface.withValues(alpha: 0.06),

    // One push for every screen: in from the trailing edge over the one it
    // came from, back along the same path under the back gesture. iOS takes
    // the same push: one look, one motion, on every phone.
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: PushPageTransitionsBuilder(),
        TargetPlatform.iOS: PushPageTransitionsBuilder(),
        TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.macOS: FadeForwardsPageTransitionsBuilder(),
      },
    ),

    // On paper, with no tint when content scrolls under it: a large title
    // collapses into this bar and the bar stays the page's own ground.
    appBarTheme: AppBarTheme(
      toolbarHeight: AppSize.appBarHeight,
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      foregroundColor: scheme.onSurface,
      titleTextStyle: textTheme.titleLarge,
      titleSpacing: AppSpace.x4,
    ),

    // Primary: a capsule in emerald, one per screen, taller than the touch
    // minimum so it reads as the focal action.
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        disabledBackgroundColor: scheme.onSurface.withValues(alpha: 0.12),
        disabledForegroundColor: scheme.onSurface.withValues(alpha: 0.38),
        minimumSize: const Size(AppSize.minTouchTarget, AppSize.primaryButton),
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.x6),
        shape: capsule,
        textStyle: AppTypography.labelLarge,
      ),
    ),

    // Secondary: a card-white capsule with a hairline and ink text. Only the
    // primary carries colour, so a row of two buttons has one focal point.
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: scheme.onSurface,
        backgroundColor: card,
        side: BorderSide(color: scheme.outlineVariant),
        minimumSize: const Size(AppSize.minTouchTarget, AppSize.minTouchTarget),
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.x6),
        shape: capsule,
        textStyle: AppTypography.labelLarge,
      ),
    ),

    // Tertiary: emerald words, no chrome.
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: linkColor,
        minimumSize: const Size(AppSize.minTouchTarget, AppSize.minTouchTarget),
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.x4),
        shape: capsule,
        textStyle: AppTypography.labelLarge,
      ),
    ),

    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: scheme.onSurface,
        minimumSize: const Size(AppSize.minTouchTarget, AppSize.minTouchTarget),
        shape: capsule,
      ),
    ),

    // The one primary creative action on a screen. Separated from every bar
    // group by position; tinted on the container so it is the only tint.
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: scheme.primary,
      foregroundColor: scheme.onPrimary,
      elevation: 0,
      focusElevation: 0,
      hoverElevation: 0,
      highlightElevation: 0,
      shape: capsule,
      extendedTextStyle: AppTypography.labelLarge,
      extendedPadding: const EdgeInsets.symmetric(horizontal: AppSpace.x5),
      iconSize: AppSize.glyphLg,
    ),

    // A card is the white step on paper, nothing more: no shadow, no tint.
    cardTheme: CardThemeData(
      color: card,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: const RoundedRectangleBorder(borderRadius: AppRadii.mdAll),
    ),

    // Capsule chips: card-white with a hairline at rest, solid emerald with
    // white words when chosen, the same selection as the tab bar.
    // A theme labelStyle replaces Material's default outright and a chip
    // resolves only the label's colour per state, so set it here or the
    // label paints with none.
    chipTheme: ChipThemeData(
      backgroundColor: card,
      selectedColor: scheme.primary,
      disabledColor: scheme.surfaceContainerLow,
      side: WidgetStateBorderSide.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? BorderSide.none
            : BorderSide(color: scheme.outlineVariant),
      ),
      shape: capsule,
      labelStyle: AppTypography.labelMedium.copyWith(
        color: WidgetStateColor.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.onPrimary
              : scheme.onSurface,
        ),
      ),
      labelPadding: const EdgeInsets.symmetric(horizontal: AppSpace.x1),
      // Label line plus padding lands on AppSize.chip at 1x. A larger text
      // size grows the chip; rows of chips size from the scaled label.
      padding: EdgeInsets.symmetric(
        horizontal: AppSpace.x3,
        vertical: (AppSize.chip - _chipLabelLine) / 2,
      ),
      showCheckmark: false,
      elevation: 0,
      pressElevation: 0,
    ),

    // Draws nothing. Boundaries come from spacing and cards; a hairline that
    // survives here is a call site that has not migrated.
    dividerTheme: const DividerThemeData(
      color: Colors.transparent,
      thickness: 0,
      space: 0,
    ),

    navigationBarTheme: NavigationBarThemeData(
      height: AppSize.bottomNav,
      backgroundColor: card,
      indicatorColor: scheme.primary,
      indicatorShape: capsule,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => AppTypography.labelMedium.copyWith(
          color: states.contains(WidgetState.selected)
              ? scheme.onSurface
              : scheme.onSurfaceVariant,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          size: AppSize.glyphXl,
          color: states.contains(WidgetState.selected)
              ? scheme.onPrimary
              : scheme.onSurfaceVariant,
        ),
      ),
    ),

    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: card,
      indicatorColor: scheme.primary,
      indicatorShape: capsule,
      elevation: 0,
      labelType: NavigationRailLabelType.all,
      selectedLabelTextStyle: AppTypography.labelMedium.copyWith(
        color: scheme.onSurface,
      ),
      unselectedLabelTextStyle: AppTypography.labelMedium.copyWith(
        color: scheme.onSurfaceVariant,
      ),
      selectedIconTheme: IconThemeData(
        size: AppSize.glyphXl,
        color: scheme.onPrimary,
      ),
      unselectedIconTheme: IconThemeData(
        size: AppSize.glyphXl,
        color: scheme.onSurfaceVariant,
      ),
    ),

    navigationDrawerTheme: NavigationDrawerThemeData(
      backgroundColor: card,
      indicatorColor: scheme.primary,
      indicatorShape: capsule,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
    ),

    // A card-white field with a hairline; the hairline turns emerald on
    // focus. No helper, no counter: the label is the placeholder and an error
    // is a border plus a trailing glyph, never a line of text under it.
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: card,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpace.x4,
        vertical: AppSpace.x4,
      ),
      isDense: true,
      floatingLabelBehavior: FloatingLabelBehavior.never,
      helperStyle: _collapsed,
      errorStyle: _collapsed,
      counterStyle: _collapsed,
      border: OutlineInputBorder(
        borderRadius: AppRadii.smAll,
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: AppRadii.smAll,
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: AppRadii.smAll,
        borderSide: BorderSide(color: scheme.primary, width: AppStroke.bold),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: AppRadii.smAll,
        borderSide: BorderSide(color: scheme.error, width: AppStroke.bold),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: AppRadii.smAll,
        borderSide: BorderSide(color: scheme.error, width: AppStroke.bold),
      ),
      labelStyle: AppTypography.bodyMedium.copyWith(
        color: scheme.onSurfaceVariant,
      ),
      hintStyle: AppTypography.bodyMedium.copyWith(
        color: scheme.onSurfaceVariant,
      ),
      prefixIconColor: scheme.onSurfaceVariant,
      suffixIconColor: scheme.onSurfaceVariant,
    ),

    // Emerges from its source, carries a handle, grows more opaque as it
    // expands. Modal sheets get the barrier; parallel ones do not. A sheet is
    // paper, so the cards inside it keep their white step.
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: scheme.surface,
      modalBackgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      modalElevation: 0,
      showDragHandle: true,
      dragHandleColor: scheme.outlineVariant,
      dragHandleSize: const Size(
        AppSize.dragHandleWidth,
        AppSize.dragHandleHeight,
      ),
      clipBehavior: Clip.antiAlias,
      shape: const RoundedRectangleBorder(borderRadius: AppRadii.sheetTop),
    ),

    dialogTheme: DialogThemeData(
      backgroundColor: card,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: const RoundedRectangleBorder(borderRadius: AppRadii.lgAll),
      titleTextStyle: textTheme.titleLarge,
      contentTextStyle: textTheme.bodyMedium,
    ),

    listTileTheme: ListTileThemeData(
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpace.x4),
      titleTextStyle: textTheme.titleSmall,
      subtitleTextStyle: textTheme.bodyMedium?.copyWith(
        color: scheme.onSurfaceVariant,
      ),
      iconColor: scheme.onSurfaceVariant,
      minVerticalPadding: AppSpace.x3,
    ),

    snackBarTheme: SnackBarThemeData(
      backgroundColor: scheme.inverseSurface,
      contentTextStyle: AppTypography.bodyMedium.copyWith(
        color: scheme.onInverseSurface,
      ),
      actionTextColor: scheme.inversePrimary,
      behavior: SnackBarBehavior.floating,
      shape: capsule,
      elevation: 0,
    ),

    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        backgroundColor: card,
        selectedBackgroundColor: scheme.primary,
        selectedForegroundColor: scheme.onPrimary,
        foregroundColor: scheme.onSurface,
        side: BorderSide(color: scheme.outlineVariant),
        shape: capsule,
        textStyle: AppTypography.labelMedium,
      ),
    ),

    // On is emerald with a white knob; off is the hairline's tone. No
    // outline either way.
    switchTheme: SwitchThemeData(
      thumbColor: const WidgetStatePropertyAll(Colors.white),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? scheme.primary
            : scheme.outlineVariant,
      ),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
    ),

    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: scheme.primary,
      linearTrackColor: scheme.surfaceContainerHighest,
      circularTrackColor: scheme.surfaceContainerHighest,
    ),
  );
}

/// One chip label line at 1x.
final _chipLabelLine =
    AppTypography.labelMedium.fontSize! * AppTypography.labelMedium.height!;

/// Zero-height style removes the helper/counter/error line and the space it reserves.
const _collapsed = TextStyle(fontSize: 0, height: 0);

/// Light. Every role is set explicitly rather than seeded, so the brand hues
/// land where the design system puts them and nowhere else.
const _lightScheme = ColorScheme(
  brightness: Brightness.light,
  primary: AppColors.emerald,
  onPrimary: AppColors.white,
  primaryContainer: AppColors.emeraldTint,
  onPrimaryContainer: AppColors.emeraldText,
  secondary: AppColors.blue,
  onSecondary: AppColors.white,
  secondaryContainer: AppColors.sky,
  onSecondaryContainer: AppColors.ink,
  // Tertiary is deliberately neutral, so no Material widget picks up a brand
  // colour as an action colour.
  tertiary: AppColors.ink700,
  onTertiary: AppColors.white,
  tertiaryContainer: AppColors.surfaceContainerHighest,
  onTertiaryContainer: AppColors.ink,
  error: AppColors.error,
  onError: AppColors.white,
  errorContainer: AppColors.errorContainer,
  onErrorContainer: AppColors.onErrorContainer,
  surface: AppColors.paper,
  onSurface: AppColors.ink,
  onSurfaceVariant: AppColors.sub,
  surfaceDim: AppColors.surfaceContainerHigh,
  surfaceBright: AppColors.white,
  surfaceContainerLowest: AppColors.white,
  surfaceContainerLow: AppColors.paper,
  surfaceContainer: AppColors.surfaceContainer,
  surfaceContainerHigh: AppColors.surfaceContainerHigh,
  surfaceContainerHighest: AppColors.surfaceContainerHighest,
  outline: AppColors.outline,
  outlineVariant: AppColors.line,
  inverseSurface: AppColors.ink,
  onInverseSurface: AppColors.paper,
  inversePrimary: AppColors.emeraldDark,
  shadow: Colors.transparent,
  scrim: Color(0x99111418),
);

/// Warm charcoal. A card is still one step brighter than the page, so
/// `surfaceContainerLowest` sits above `surface` here too.
const _darkScheme = ColorScheme(
  brightness: Brightness.dark,
  primary: AppColors.emeraldDark,
  onPrimary: AppColors.onEmeraldDark,
  primaryContainer: AppColors.emeraldTintDark,
  onPrimaryContainer: AppColors.charcoalInk,
  secondary: AppColors.blueDark,
  onSecondary: AppColors.charcoal,
  secondaryContainer: AppColors.skyDark,
  onSecondaryContainer: AppColors.charcoalInk,
  tertiary: AppColors.charcoalSub,
  onTertiary: AppColors.charcoal,
  tertiaryContainer: AppColors.charcoalHighest,
  onTertiaryContainer: AppColors.charcoalInk,
  error: Color(0xFFF0A5A5),
  onError: Color(0xFF4A1F1F),
  errorContainer: Color(0xFF4A1F1F),
  onErrorContainer: Color(0xFFF0A5A5),
  surface: AppColors.charcoal,
  onSurface: AppColors.charcoalInk,
  onSurfaceVariant: AppColors.charcoalSub,
  surfaceDim: AppColors.charcoalDim,
  surfaceBright: AppColors.charcoalRaised,
  surfaceContainerLowest: AppColors.charcoalCard,
  surfaceContainerLow: AppColors.charcoal,
  surfaceContainer: AppColors.charcoalRaised,
  surfaceContainerHigh: AppColors.charcoalHigh,
  surfaceContainerHighest: AppColors.charcoalHighest,
  outline: AppColors.charcoalOutline,
  outlineVariant: AppColors.charcoalLine,
  inverseSurface: AppColors.charcoalInk,
  onInverseSurface: AppColors.charcoal,
  inversePrimary: AppColors.emerald,
  shadow: Colors.transparent,
  scrim: Color(0xB3000000),
);
