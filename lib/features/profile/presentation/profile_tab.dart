import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";

import "../../../core/router/app_router.dart";
import "../../../core/theme/app_dimens.dart";
import "../../../core/theme/app_icons.dart";
import "../../../core/theme/app_typography.dart";
import "../../../core/theme/lakbayan_colors.dart";
import "../../../core/widgets/chrome/floating_tab_bar.dart";
import "../../../core/widgets/content/grouped_section.dart";
import "../../../core/widgets/motion/motion.dart";
import "../../auth/domain/auth_providers.dart";
import "../../destinations/domain/destination_providers.dart";
import "../../explore/domain/home_tab.dart";
import "sample_photo_credits_sheet.dart";

/// Profile (D-16).
///
/// **The screen's one job.** What is mine, and how the app behaves for me.
///
/// **Emotion.** Ownership.
///
/// **Anatomy.** The one brand moment, a solid green block: the avatar, the
/// name as the screen's heading, and one line.
/// Three plain rows: Saved places, Downloaded towns and Settings, the one
/// home for future settings ([SettingsScreen]). Sign out last, alone.
class ProfileTab extends ConsumerWidget {
  const ProfileTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isGuest = ref.watch(guestModeProvider);

    return EntranceScope(
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          AppSpace.gutter,
          MediaQuery.viewPaddingOf(context).top + AppSpace.x2,
          AppSpace.gutter,
          FloatingTabBar.clearance(context) + AppSpace.section,
        ),
        children: [
          const Entrance(child: _BrandBlock()),
          const SizedBox(height: AppSpace.section),
          const Entrance(order: 1, child: _Mine()),
          const SizedBox(height: AppSpace.section),
          Pressable(
            child: isGuest
                ? FilledButton(
                    onPressed: () =>
                        ref.read(guestModeProvider.notifier).disable(),
                    child: const Text("Sign in"),
                  )
                : OutlinedButton(
                    onPressed: () =>
                        ref.read(authControllerProvider.notifier).signOut(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: context.lakbayan.closed,
                      minimumSize: const Size.fromHeight(AppSize.primaryButton),
                    ),
                    child: const Text("Sign out"),
                  ),
          ),
          // Not in release — profile builds keep the sample-data switch for perf measurement.
          if (!kReleaseMode) ...[
            const SizedBox(height: AppSpace.section),
            const _DebugRows(),
          ],
        ],
      ),
    );
  }
}

/// The sanctioned full-strength green area. Nothing else on the screen is
/// tinted. The avatar leads, large, and the name is the screen's heading.
class _BrandBlock extends ConsumerWidget {
  const _BrandBlock();

  static const _avatar = AppSize.avatar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final isGuest = ref.watch(guestModeProvider);
    final user = ref.watch(authStateProvider).value;
    final name = isGuest
        ? "Browsing as a guest"
        : (user?.displayName?.trim().isNotEmpty ?? false)
        ? user!.displayName!.trim()
        : (user?.label ?? "Signed in");
    final line = isGuest
        ? "Sign in to keep your saves and plans"
        : (user?.email ?? "");
    final initial = Text(
      name.isEmpty ? "?" : name.characters.first.toUpperCase(),
      style: AppTypography.titleMedium.copyWith(color: scheme.primary),
    );
    final photo = isGuest ? null : user?.photoUrl;

    return Material(
      color: scheme.primary,
      shape: const RoundedRectangleBorder(borderRadius: AppRadii.lgAll),
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.x3),
        child: Row(
          children: [
            Container(
              width: _avatar,
              height: _avatar,
              decoration: ShapeDecoration(
                color: scheme.onPrimary,
                shape: const CircleBorder(),
              ),
              clipBehavior: Clip.antiAlias,
              alignment: Alignment.center,
              child: photo == null
                  ? initial
                  : Image.network(
                      photo,
                      fit: BoxFit.cover,
                      width: _avatar,
                      height: _avatar,
                      cacheWidth: (_avatar * 3).round(),
                      errorBuilder: (_, _, _) => initial,
                    ),
            ),
            const SizedBox(width: AppSpace.x3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      name,
                      style: AppTypography.titleMedium.copyWith(
                        color: scheme.onPrimary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (line.isNotEmpty)
                    Text(
                      line,
                      style: AppTypography.bodyMedium.copyWith(
                        color: scheme.onPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// What is mine and how the app behaves, as plain rows on the white ground,
/// each a glyph, where it goes and a chevron (coloured tiles retired
/// 2026-09-26). The glyphs keep their meaning's colour: the red of the saved
/// heart, the blue of downloads, ink for settings.
class _Mine extends StatelessWidget {
  const _Mine();

  @override
  Widget build(BuildContext context) {
    final brand = context.lakbayan;
    return GroupedSection(
      children: [
        GroupedRow(
          leadingGlyph: AppIcons.favoriteFilled,
          glyphColor: brand.save,
          title: "Saved places",
          onTap: () => context.push(Routes.saved),
        ),
        GroupedRow(
          leadingGlyph: AppIcons.download,
          glyphColor: brand.spatial,
          title: "Downloaded towns",
          onTap: () => context.push(Routes.downloads),
        ),
        GroupedRow(
          leadingGlyph: AppIcons.settings,
          title: "Settings",
          onTap: () => context.push(Routes.settings),
        ),
      ],
    );
  }
}

/// Debug and profile only: the sample-data switch, and in debug the living
/// specimen, whose route exists only in debug builds.
class _DebugRows extends ConsumerWidget {
  const _DebugRows();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sample = ref.watch(sampleDataProvider);
    return Wrap(
      spacing: AppSpace.x2,
      children: [
        if (kDebugMode)
          TextButton(
            onPressed: () => context.push(Routes.designSystem),
            child: const Text("Design system"),
          ),
        TextButton(
          onPressed: () {
            ref.read(sampleDataProvider.notifier).toggle();
            ref.read(selectedHomeTabProvider.notifier).select(HomeTab.explore);
          },
          child: Text(sample ? "Use live data" : "Preview with sample data"),
        ),
        // Beside the switch that shows them, and there whether or not the
        // preview is on: the photographs are in the build either way.
        TextButton(
          onPressed: () => showSamplePhotoCredits(context),
          child: const Text("Photo credits"),
        ),
      ],
    );
  }
}
