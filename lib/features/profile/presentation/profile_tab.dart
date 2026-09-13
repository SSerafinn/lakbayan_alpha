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
import "../../../core/widgets/grouped_section.dart";
import "../../../core/widgets/scroll_edge.dart";
import "../../auth/domain/auth_providers.dart";
import "../../destinations/domain/destination_providers.dart";
import "../../explore/domain/home_tab.dart";

/// Profile (redesign 2e).
///
/// **The screen's one job.** What is mine, and the one setting.
///
/// **Emotion.** Ownership.
///
/// **Anatomy.** The title; the one brand moment, a solid green block with
/// the avatar, name and one line; a grouped section of what is theirs (Saved
/// places, Downloaded towns), each with the glyph of the action that made
/// it; a grouped section of settings with the value as trailing text; then
/// Sign out as a white capsule with a red label.
class ProfileTab extends ConsumerWidget {
  const ProfileTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isGuest = ref.watch(guestModeProvider);
    final topInset = MediaQuery.viewPaddingOf(context).top;

    return ListView(
      padding: EdgeInsets.fromLTRB(
        AppSpace.gutter,
        topInset + AppSpace.x2,
        AppSpace.gutter,
        ScrollEdge.homeBarHeight(context) + AppSpace.section,
      ),
      children: [
        Text("Profile", style: AppTypography.titleLarge),
        const SizedBox(height: AppSpace.section),
        _BrandBlock(isGuest: isGuest),
        const SizedBox(height: AppSpace.section),
        const _Mine(),
        const SizedBox(height: AppSpace.section),
        const _Settings(),
        const SizedBox(height: AppSpace.section),
        if (isGuest)
          FilledButton(
            onPressed: () => ref.read(guestModeProvider.notifier).disable(),
            child: const Text("Sign in"),
          )
        else
          OutlinedButton(
            onPressed: () =>
                ref.read(authControllerProvider.notifier).signOut(),
            style: OutlinedButton.styleFrom(
              foregroundColor: context.lakbayan.closed,
              minimumSize: const Size.fromHeight(AppSize.primaryButton),
            ),
            child: const Text("Sign out"),
          ),
        if (kDebugMode) ...[
          const SizedBox(height: AppSpace.section),
          const _DebugRows(),
        ],
      ],
    );
  }
}

/// The sanctioned full-strength green area. Nothing else on the screen is
/// tinted.
class _BrandBlock extends ConsumerWidget {
  const _BrandBlock({required this.isGuest});

  final bool isGuest;

  static const _avatar = 56.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final user = ref.watch(authStateProvider).value;
    final name = isGuest
        ? "Browsing as a guest"
        : (user?.displayName?.trim().isNotEmpty ?? false)
        ? user!.displayName!.trim()
        : (user?.label ?? "Signed in");
    final line = isGuest
        ? "Sign in to keep your saves and plans"
        : (user?.email ?? "");
    final initial = name.isEmpty ? "?" : name.characters.first.toUpperCase();

    return Material(
      color: scheme.primary,
      shape: const RoundedRectangleBorder(borderRadius: AppRadii.lgAll),
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.x4),
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
              child: user?.photoUrl == null || isGuest
                  ? Text(
                      initial,
                      style: AppTypography.titleMedium.copyWith(
                        color: scheme.primary,
                      ),
                    )
                  : Image.network(
                      user!.photoUrl!,
                      fit: BoxFit.cover,
                      width: _avatar,
                      height: _avatar,
                      cacheWidth: (_avatar * 3).round(),
                      errorBuilder: (_, _, _) => Text(
                        initial,
                        style: AppTypography.titleMedium.copyWith(
                          color: scheme.primary,
                        ),
                      ),
                    ),
            ),
            const SizedBox(width: AppSpace.x4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    name,
                    style: AppTypography.titleMedium.copyWith(
                      color: scheme.onPrimary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (line.isNotEmpty) ...[
                    const SizedBox(height: AppSpace.x1),
                    Text(
                      line,
                      style: AppTypography.bodyMedium.copyWith(
                        color: scheme.onPrimary.withValues(alpha: 0.85),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Saved places and downloaded towns: the two places a glyph is allowed
/// here, because each maps to an established action.
class _Mine extends ConsumerWidget {
  const _Mine();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brand = context.lakbayan;

    // No second line: what is saved or downloaded is the list behind the
    // row, not a summary under it (no dangling text).
    return GroupedSection(
      children: [
        GroupedRow(
          title: "Saved places",
          leadingGlyph: AppIcons.favoriteFilled,
          glyphColor: brand.save,
          onTap: () => context.push(Routes.saved),
        ),
        GroupedRow(
          title: "Downloaded towns",
          leadingGlyph: AppIcons.download,
          glyphColor: brand.spatial,
          onTap: () => context.push(Routes.downloads),
        ),
      ],
    );
  }
}

/// The one setting so far: appearance. A menu anchored to the row, so the
/// choice comes from the thing that was tapped (design doc 04).
class _Settings extends ConsumerWidget {
  const _Settings();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(appThemeModeProvider);
    final scheme = Theme.of(context).colorScheme;

    return GroupedSection(
      children: [
        MenuAnchor(
          menuChildren: [
            for (final option in ThemeMode.values)
              MenuItemButton(
                leadingIcon: option == mode
                    ? const Icon(AppIcons.check)
                    : const SizedBox(width: AppSpace.x6),
                onPressed: () =>
                    ref.read(appThemeModeProvider.notifier).select(option),
                child: Text(option.label),
              ),
          ],
          builder: (context, controller, _) => GroupedRow(
            title: "Appearance",
            trailing: Text(
              mode.label,
              style: AppTypography.secondLine.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            onTap: controller.isOpen ? controller.close : controller.open,
          ),
        ),
      ],
    );
  }
}

/// Debug only: the living specimen and the sample-data switch.
class _DebugRows extends ConsumerWidget {
  const _DebugRows();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sample = ref.watch(sampleDataProvider);
    return GroupedSection(
      heading: "Debug",
      children: [
        GroupedRow(
          title: "Design system",
          onTap: () => context.push(Routes.designSystem),
        ),
        GroupedRow(
          title: sample ? "Use live data" : "Preview with sample data",
          onTap: () {
            ref.read(sampleDataProvider.notifier).toggle();
            ref.read(selectedHomeTabProvider.notifier).select(HomeTab.explore);
          },
        ),
      ],
    );
  }
}
