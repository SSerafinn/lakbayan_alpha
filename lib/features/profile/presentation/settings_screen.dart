import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";

import "../../../core/router/app_router.dart";
import "../../../core/theme/app_dimens.dart";
import "../../../core/theme/app_icons.dart";
import "../../../core/theme/app_theme_mode.dart";
import "../../../core/theme/app_typography.dart";
import "../../../core/theme/lakbayan_colors.dart";
import "../../../core/widgets/chrome/app_menu.dart";
import "../../../core/widgets/chrome/page_title.dart";
import "../../../core/widgets/content/grouped_section.dart";
import "../../../core/widgets/motion/motion.dart";
import "../../auth/domain/auth_providers.dart";
import "../../destinations/domain/destination_providers.dart";
import "../../explore/domain/home_tab.dart";
import "../../offline/domain/offline_providers.dart";
import "sample_photo_credits_sheet.dart";

/// Settings (D-19). **One job:** make the app behave the way I need it to.
/// **Emotion:** calm control; nothing here surprises.
///
/// **Anatomy.** Back and the large title; then one white card per concern
/// under its short heading, each row a label with its value, chevron or
/// switch trailing, and no row glyphs. Signing out last, alone. Reached
/// from Profile's gear. Only settings that do something are listed; a
/// placeholder row would be a promise the app does not keep.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isGuest = ref.watch(guestModeProvider);
    final email = isGuest ? null : ref.watch(authStateProvider).value?.email;
    final towns = ref.watch(townsOnPhoneProvider);
    final groups = [
      const GroupedSection(heading: "Appearance", children: [_ThemeRow()]),
      const GroupedSection(
        heading: "Accessibility",
        children: [_ReduceMotionRow()],
      ),
      GroupedSection(
        heading: "Offline",
        children: [
          GroupedRow(
            title: "Downloaded Towns",
            trailing: _Value("$towns", glyph: AppIcons.chevron),
            onTap: () => context.push(Routes.downloads),
          ),
        ],
      ),
      GroupedSection(
        heading: "Support",
        children: [
          GroupedRow(
            title: "Help and Emergency Lines",
            onTap: () => context.push(Routes.help),
          ),
          GroupedRow(
            title: "Privacy Policy",
            onTap: () => context.push(Routes.privacy),
          ),
          GroupedRow(
            title: "Terms of Use",
            onTap: () => context.push(Routes.terms),
          ),
        ],
      ),
      if (email != null)
        GroupedSection(
          heading: "Account",
          children: [GroupedRow(title: "Email", trailing: _Value(email))],
        ),
      const _Account(),
      // Not in release: profile builds keep the sample data for measuring.
      if (!kReleaseMode) const _Developer(),
    ];

    return EntranceScope(
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              AppSpace.gutter,
              AppSpace.x2,
              AppSpace.gutter,
              MediaQuery.viewPaddingOf(context).bottom + AppSpace.section,
            ),
            children: [
              const PageTitle("Settings"),
              for (final (index, group) in groups.indexed) ...[
                const SizedBox(height: AppSpace.section),
                Entrance(order: index + 1, child: group),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A row's current value, quiet, before its accessory. A long one gives way
/// before the row's own label does.
class _Value extends StatelessWidget {
  const _Value(this.value, {this.glyph});

  final String value;
  final IconData? glyph;

  @override
  Widget build(BuildContext context) {
    final quiet = Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width / 2,
          ),
          child: Text(
            value,
            style: AppTypography.bodyLarge.copyWith(color: quiet),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (glyph != null) ...[
          const SizedBox(width: AppSpace.near),
          SizedBox(
            width: AppSize.minTouchTarget,
            child: Icon(glyph, size: AppSize.glyphMd, color: quiet),
          ),
        ],
      ],
    );
  }
}

/// System, light or dark: the row shows the choice, and a tap grows the
/// menu of the three out of it, the chosen one checked.
class _ThemeRow extends ConsumerWidget {
  const _ThemeRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(appThemeModeProvider);
    return AppMenu(
      groups: [
        [
          for (final option in ThemeMode.values)
            AppMenuItem(
              label: option.label,
              icon: switch (option) {
                ThemeMode.system => AppIcons.themeSystem,
                ThemeMode.light => AppIcons.themeLight,
                ThemeMode.dark => AppIcons.themeDark,
              },
              selected: option == mode,
              onSelected: () =>
                  ref.read(appThemeModeProvider.notifier).select(option),
            ),
        ],
      ],
      builder: (context, menu) => GroupedRow(
        title: "Theme",
        trailing: _Value(mode.label, glyph: AppIcons.menu),
        onTap: menu.open,
      ),
    );
  }
}

/// Calmer motion: springs become cross-fades everywhere, on top of the
/// phone's own setting. The row and the switch are one target.
class _ReduceMotionRow extends ConsumerWidget {
  const _ReduceMotionRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final on = ref.watch(reduceMotionProvider);
    void flip() => ref.read(reduceMotionProvider.notifier).set(!on);
    return MergeSemantics(
      child: GroupedRow(
        title: "Reduce Motion",
        trailing: Switch(value: on, onChanged: (_) => flip()),
        onTap: flip,
      ),
    );
  }
}

/// Sign Out on its own card, red, or Sign In for a guest.
class _Account extends ConsumerWidget {
  const _Account();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isGuest = ref.watch(guestModeProvider);
    return Pressable(
      child: TextButton(
        onPressed: isGuest
            ? () => ref.read(guestModeProvider.notifier).disable()
            : () => ref.read(authControllerProvider.notifier).signOut(),
        style: TextButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
          foregroundColor: isGuest ? null : context.lakbayan.closed,
          minimumSize: const Size.fromHeight(AppSize.primaryButton),
          shape: const RoundedRectangleBorder(borderRadius: AppRadii.mdAll),
          textStyle: AppTypography.labelLarge,
        ),
        child: Text(isGuest ? "Sign In" : "Sign Out"),
      ),
    );
  }
}

/// Debug and profile builds only: the living specimen (debug), the sample
/// data, and the credits for its photographs, there whether or not the
/// preview is on, since they are in the build either way.
class _Developer extends ConsumerWidget {
  const _Developer();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sample = ref.watch(sampleDataProvider);
    return GroupedSection(
      heading: "Developer",
      children: [
        if (kDebugMode)
          GroupedRow(
            title: "Design System",
            onTap: () => context.push(Routes.designSystem),
          ),
        MergeSemantics(
          child: GroupedRow(
            title: "Sample Data",
            trailing: Switch(
              value: sample,
              onChanged: (_) => _toggleSample(ref),
            ),
            onTap: () => _toggleSample(ref),
          ),
        ),
        GroupedRow(
          title: "Photo Credits",
          onTap: () => showSamplePhotoCredits(context),
        ),
      ],
    );
  }

  /// The preview shows on Explore, so that is where the tab goes.
  static void _toggleSample(WidgetRef ref) {
    ref.read(sampleDataProvider.notifier).toggle();
    ref.read(selectedHomeTabProvider.notifier).select(HomeTab.explore);
  }
}
