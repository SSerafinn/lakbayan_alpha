import "dart:math" show min;

import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";

import "../../../core/models/destination.dart";
import "../../../core/router/app_router.dart";
import "../../../core/theme/app_dimens.dart";
import "../../../core/theme/app_icons.dart";
import "../../../core/theme/app_typography.dart";
import "../../../core/theme/lakbayan_colors.dart";
import "../../../core/widgets/chrome/floating_tab_bar.dart";
import "../../../core/widgets/chrome/system_bars.dart";
import "../../../core/widgets/content/media_tile.dart";
import "../../../core/widgets/content/section_heading.dart";
import "../../../core/widgets/content/storage_image.dart";
import "../../../core/widgets/controls/symbol_button.dart";
import "../../../core/widgets/motion/motion.dart";
import "../../../core/widgets/motion/page_transitions.dart";
import "../../auth/domain/auth_providers.dart";
import "../../destinations/domain/saved_destinations.dart";
import "../../explore/domain/home_tab.dart";
import "../../itineraries/domain/itinerary_providers.dart";
import "../../offline/domain/offline_providers.dart";
import "user_avatar.dart";

/// Profile (D-19). **One job:** what is mine. **Emotion:** ownership.
///
/// **Anatomy.** A cover from my own saved places (a tap moves to the next),
/// the gear to Settings over it, my avatar half over its foot and my name
/// large. Then three counts, each the label of what it opens: Saved, Trips,
/// Offline. Then the saved places as photos, See All for the rest. A guest
/// gets Sign In under the name.
class ProfileTab extends ConsumerStatefulWidget {
  const ProfileTab({super.key});

  @override
  ConsumerState<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends ConsumerState<ProfileTab> {
  final _scroll = ScrollController();

  /// Which saved place's photo is the cover. In memory, as the saves are
  /// until they sync (`my-docs/backend-requests/saved-destinations.md`).
  int _cover = 0;

  /// Saved places shown here; See All has the rest.
  static const _shown = 6;

  /// About this much of the screen goes to the cover.
  static const _share = 0.25;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final saved = ref.watch(savedPlacesProvider).value ?? const <Destination>[];
    final isGuest = ref.watch(guestModeProvider);
    final cover = (MediaQuery.sizeOf(context).height * _share).ceilToDouble();
    const gutter = AppSpace.gutter;

    return EntranceScope(
      child: Stack(
        children: [
          CustomScrollView(
            controller: _scroll,
            slivers: [
              SliverToBoxAdapter(
                child: _Header(
                  height: cover,
                  photo: saved.isEmpty
                      ? null
                      : saved[_cover % saved.length].coverImage,
                  onNext: saved.length < 2
                      ? null
                      : () => setState(() => _cover++),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  gutter,
                  AppSpace.x2,
                  gutter,
                  0,
                ),
                sliver: SliverList.list(
                  children: [
                    const Entrance(child: _Name()),
                    if (isGuest) ...[
                      const SizedBox(height: AppSpace.gutter),
                      Entrance(
                        order: 1,
                        child: Pressable(
                          child: FilledButton(
                            onPressed: () =>
                                ref.read(guestModeProvider.notifier).disable(),
                            child: const Text("Sign In"),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpace.section),
                    Entrance(order: 2, child: _Counts(saved: saved.length)),
                    if (saved.isNotEmpty) ...[
                      const SizedBox(height: AppSpace.section),
                      SectionHeading(
                        "Saved",
                        onSeeAll: () => context.push(Routes.saved),
                      ),
                    ],
                  ],
                ),
              ),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  gutter,
                  0,
                  gutter,
                  FloatingTabBar.clearance(context) + AppSpace.section,
                ),
                sliver: SliverGrid.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: AppSpace.near,
                    crossAxisSpacing: AppSpace.near,
                  ),
                  itemCount: min(saved.length, _shown),
                  itemBuilder: (context, index) => _Saved(place: saved[index]),
                ),
              ),
            ],
          ),
          // The cover keeps the status bar at rest; the paper closes in
          // under it as the name arrives there.
          StatusBarGround.below(scroll: _scroll, contentTop: cover),
        ],
      ),
    );
  }
}

/// The cover, the gear and the change of cover on it, and the avatar half
/// over its foot. With nothing saved, the cover is the mint wash.
class _Header extends StatelessWidget {
  const _Header({
    required this.height,
    required this.photo,
    required this.onNext,
  });

  final double height;
  final String? photo;
  final VoidCallback? onNext;

  static const _avatar = AppSize.avatar;

  /// The paper ring that lifts the avatar off the cover.
  static const _ring = AppSpace.x1;

  @override
  Widget build(BuildContext context) {
    final brand = context.lakbayan;
    final top = MediaQuery.viewPaddingOf(context).top;
    final photo = this.photo;

    return SizedBox(
      height: height + _avatar / 2,
      child: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: height,
            child: photo == null
                ? ColoredBox(color: brand.mint)
                : SystemBars(
                    overPhoto: true,
                    child: FadeSwap(id: photo, child: CoverImage(photo)),
                  ),
          ),
          Positioned(
            top: top + AppSpace.x2,
            right: AppSpace.gutter,
            child: SymbolButton(
              icon: AppIcons.settings,
              tooltip: "Settings",
              onTap: () => context.push(Routes.settings),
            ),
          ),
          if (onNext != null)
            Positioned(
              top: height - AppSpace.x3 - AppSize.symbolButton,
              right: AppSpace.gutter,
              child: SymbolButton(
                icon: AppIcons.cover,
                tooltip: "Change cover photo",
                onTap: onNext,
              ),
            ),
          const Positioned(
            left: AppSpace.gutter + AppSpace.x1,
            bottom: 0,
            child: UserAvatar(size: _avatar, ring: _ring),
          ),
        ],
      ),
    );
  }
}

/// My name, the screen's heading; a guest is Guest.
class _Name extends ConsumerWidget {
  const _Name();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).value;
    final name = ref.watch(guestModeProvider)
        ? "Guest"
        : user?.label ?? "Signed In";
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.x1),
      child: Semantics(
        header: true,
        child: Text(
          name,
          style: AppTypography.hero,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

/// Saved, Trips and Offline on one card, each count the label of the place
/// it opens (D-19).
class _Counts extends ConsumerWidget {
  const _Counts({required this.saved});

  final int saved;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trips = ref.watch(myItinerariesProvider).value?.length ?? 0;
    final towns = ref.watch(townsOnPhoneProvider);
    String some(int count, String noun) =>
        "$count $noun${count == 1 ? "" : "s"}";

    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(borderRadius: AppRadii.mdAll),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          _Count(
            count: saved,
            label: "Saved",
            spoken: some(saved, "saved place"),
            onTap: () => context.push(Routes.saved),
          ),
          _Count(
            count: trips,
            label: "Trips",
            spoken: some(trips, "trip"),
            onTap: () => ref
                .read(selectedHomeTabProvider.notifier)
                .select(HomeTab.itineraries),
          ),
          _Count(
            count: towns,
            label: "Offline",
            spoken: "${some(towns, "town")} saved offline",
            onTap: () => context.push(Routes.downloads),
          ),
        ],
      ),
    );
  }
}

class _Count extends StatelessWidget {
  const _Count({
    required this.count,
    required this.label,
    required this.spoken,
    required this.onTap,
  });

  final int count;
  final String label;

  /// The count and its noun read as one: "6 saved places".
  final String spoken;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Semantics(
      button: true,
      label: spoken,
      onTap: onTap,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpace.x3),
          child: Column(
            children: [
              Text("$count", style: AppTypography.titleLarge),
              Text(
                label,
                style: AppTypography.labelMedium.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// One saved place as its photo, named for a screen reader; it opens the
/// place, zooming.
class _Saved extends StatelessWidget {
  const _Saved({required this.place});

  final Destination place;

  @override
  Widget build(BuildContext context) => MergeSemantics(
    child: Semantics(
      label: place.name,
      child: MediaTile(
        media: PhotoHero(
          tag: coverHeroTag(place.id, HeroSource.profile),
          child: CoverImage(place.coverImage),
        ),
        aspectRatio: 1,
        radius: AppRadii.sm,
        onTap: () => context.push(
          Routes.destination(place.id, from: HeroSource.profile),
        ),
      ),
    ),
  );
}
