import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";

import "../../../core/errors/error_copy.dart";
import "../../../core/errors/local_first.dart";
import "../../../core/models/destination.dart";
import "../../../core/router/app_router.dart";
import "../../../core/theme/app_dimens.dart";
import "../../../core/theme/app_icons.dart";
import "../../../core/theme/app_typography.dart";
import "../../../core/widgets/chrome/system_bars.dart";
import "../../../core/widgets/content/media_tile.dart";
import "../../../core/widgets/content/quiet_note.dart";
import "../../../core/widgets/content/storage_image.dart";
import "../../../core/widgets/controls/kind_rail.dart";
import "../../../core/widgets/controls/symbol_button.dart";
import "../../../core/widgets/motion/page_transitions.dart";
import "../../offline/domain/offline_providers.dart";
import "../../offline/presentation/town_download_button.dart";
import "../domain/destination_providers.dart";
import "place_pills.dart";
import "save_heart.dart";

/// One town. **Job:** pick a place in a town you are in or going to.
/// **Emotion:** the town laid out in front of you.
///
/// Its photo, zoomed from where it was tapped, with back and taking it
/// offline pinned over it. The paper page rises over the photo's foot with
/// the name, the kinds as a glyph rail, the first place large and the rest as a
/// grid of photos, each name on its photo (D-19).
class TownScreen extends ConsumerWidget {
  const TownScreen({required this.name, this.from, super.key});

  final String name;
  final HeroSource? from;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final all = ref.watch(allDestinationsProvider);
    final town = ref.watch(
      townsProvider.select(
        (towns) => towns.where((town) => town.name == name).firstOrNull,
      ),
    );
    return all.whenLocalFirst(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, _) => MessageScreen(
        errorCopy("Couldn't load this town.", error),
        onRetry: () => ref.invalidate(allDestinationsProvider),
      ),
      data: (_) => town == null
          ? const MessageScreen("There are no places in this town yet.")
          : _TownPage(town: town, from: from),
    );
  }
}

class _TownPage extends StatefulWidget {
  const _TownPage({required this.town, required this.from});

  final Town town;
  final HeroSource? from;

  @override
  State<_TownPage> createState() => _TownPageState();
}

class _TownPageState extends State<_TownPage> {
  final _scroll = ScrollController();
  DestinationCategory? _kind;

  /// About this much of the screen goes to the photo.
  static const _share = 0.32;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final town = widget.town;
    final kind = _kind;
    final places = kind == null ? town.places : town.byKind[kind] ?? const [];
    final stage = (MediaQuery.sizeOf(context).height * _share).ceilToDouble();
    final first = places.firstOrNull;
    const gutter = AppSpace.gutter;

    return Scaffold(
      body: Stack(
        children: [
          CustomScrollView(
            controller: _scroll,
            slivers: [
              SliverToBoxAdapter(
                child: _Photo(town: town, from: widget.from, height: stage),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: gutter),
                sliver: SliverToBoxAdapter(
                  child: Semantics(
                    header: true,
                    child: Text(town.name, style: AppTypography.hero),
                  ),
                ),
              ),
              if (town.byKind.length > 1)
                SliverPadding(
                  padding: const EdgeInsets.only(top: AppSpace.x3),
                  sliver: SliverToBoxAdapter(
                    child: KindRail(
                      items: [
                        KindRailItem(
                          label: "All",
                          glyph: AppIcons.grid,
                          selectedGlyph: AppIcons.grid,
                          selected: kind == null,
                          onTap: () => setState(() => _kind = null),
                        ),
                        for (final each in town.byKind.keys)
                          KindRailItem(
                            label: each.label,
                            glyph: AppIcons.kind(each),
                            selectedGlyph: AppIcons.kind(each, filled: true),
                            selected: kind == each,
                            onTap: () => setState(() => _kind = each),
                          ),
                      ],
                    ),
                  ),
                ),
              if (first != null)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    gutter,
                    AppSpace.x3,
                    gutter,
                    0,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: _Place(place: first, large: true),
                  ),
                ),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  gutter,
                  AppSpace.x2,
                  gutter,
                  MediaQuery.viewPaddingOf(context).bottom + AppSpace.section,
                ),
                sliver: SliverGrid.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: AppSpace.x2,
                    crossAxisSpacing: AppSpace.x2,
                    childAspectRatio: 5 / 6,
                  ),
                  itemCount: places.isEmpty ? 0 : places.length - 1,
                  itemBuilder: (context, index) =>
                      _Place(place: places[index + 1]),
                ),
              ),
            ],
          ),
          StatusBarGround.below(scroll: _scroll, contentTop: stage),
          Positioned(
            top: MediaQuery.viewPaddingOf(context).top + AppSpace.x2,
            left: AppSpace.x2,
            right: AppSpace.x2,
            child: Row(
              children: [
                SymbolButton(
                  icon: AppIcons.back,
                  tooltip: "Back",
                  onTap: context.popOrHome,
                ),
                const Spacer(),
                _Offline(town: town.name),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The town's photo, its foot under the page's rounded paper edge.
class _Photo extends StatelessWidget {
  const _Photo({required this.town, required this.from, required this.height});

  final Town town;
  final HeroSource? from;
  final double height;

  /// The page's rounded edge over the photo's foot.
  static const _edge = AppSpace.x6;

  @override
  Widget build(BuildContext context) {
    final from = this.from;
    final photo = CoverImage(town.cover);
    return SizedBox(
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (from == null)
            photo
          else
            PhotoHero(tag: townHeroTag(town.name, from), child: photo),
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            bottom: _edge,
            child: SystemBars(overPhoto: true, child: SizedBox.expand()),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: _edge,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: AppRadii.sheetTop,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A place as its photo with the name on it: the first one wide with the
/// heart, the rest in the grid. The scan glyph where there are exhibits.
class _Place extends StatelessWidget {
  const _Place({required this.place, this.large = false});

  final Destination place;
  final bool large;

  @override
  Widget build(BuildContext context) => MediaTile(
    media: PhotoHero(
      tag: coverHeroTag(place.id, HeroSource.town),
      child: CoverImage(place.coverImage),
    ),
    aspectRatio: large ? 15 / 8 : 5 / 6,
    overlay: true,
    dense: !large,
    radius: AppRadii.md,
    title: place.name,
    pill: placePills(place),
    trailing: large ? SaveHeart(place.id, style: SaveHeartStyle.tile) : null,
    onTap: () =>
        context.push(Routes.destination(place.id, from: HeroSource.town)),
  );
}

/// Taking the town offline from its own page; once it is on the phone, the
/// check opens Offline. Not there when the province has no download ready
/// for the town.
class _Offline extends ConsumerWidget {
  const _Offline({required this.town});

  final String town;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bundle = ref.watch(
      offlineBundlesProvider.select(
        (bundles) => bundles.value
            ?.where((bundle) => bundle.name == town && bundle.isDownloadable)
            .firstOrNull,
      ),
    );
    if (bundle == null) return const SizedBox.shrink();
    return TownDownloadButton(
      bundle: bundle,
      done: SymbolButton(
        icon: AppIcons.check,
        tooltip: "$town is on this phone",
        onTap: () => context.push(Routes.downloads),
      ),
    );
  }
}
