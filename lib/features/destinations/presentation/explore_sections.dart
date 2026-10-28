import "dart:async";

import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "package:motor/motor.dart";

import "../../../core/errors/error_copy.dart";
import "../../../core/errors/local_first.dart";
import "../../../core/models/destination.dart";
import "../../../core/models/guide.dart";
import "../../../core/router/app_router.dart";
import "../../../core/theme/app_dimens.dart";
import "../../../core/theme/app_icons.dart";
import "../../../core/theme/app_motion.dart";
import "../../../core/theme/app_typography.dart";
import "../../../core/theme/lakbayan_colors.dart";
import "../../../core/widgets/content/media_tile.dart";
import "../../../core/widgets/content/quiet_note.dart";
import "../../../core/widgets/content/section_heading.dart";
import "../../../core/widgets/content/storage_image.dart";
import "../../../core/widgets/motion/motion.dart";
import "../../../core/widgets/motion/page_transitions.dart";
import "../../guides/domain/guide_providers.dart";
import "../../itineraries/domain/itinerary_providers.dart";
import "../../itineraries/presentation/tour_tile.dart";
import "../domain/destination_providers.dart";
import "../domain/recently_viewed.dart";
import "place_photo.dart";

// Explore's feed under the featured cards, one widget per section, in the
// order the screen shows them (see `ExploreScreen`). Every photo carries its
// caption on its own scrim, so no section spends a line of white under a
// picture.

/// A section of photos on its own white card, so a dark photo meets a
/// surface and not the page behind it, and the feed steps paper, card, paper
/// all the way down. The photos inside take concentric corners.
class SectionCard extends StatelessWidget {
  const SectionCard({required this.child, super.key});

  final Widget child;

  /// The gap from the card's edge to its photos, which `MediaTile` also
  /// assumes when it derives its own radius.
  static const inset = AppSpace.x3;

  @override
  // No clip of its own: everything inside sits [inset] in from the edge and
  // clips itself (each photo its corners, a rail its ends), so a clip here
  // would only add a layer over a scrolling rail (STANDARDS 10.4).
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surfaceContainerLowest,
    shape: const RoundedRectangleBorder(borderRadius: AppRadii.lgAll),
    child: Padding(
      padding: const EdgeInsets.all(inset),
      child: ParentRadius(radius: AppRadii.lg, child: child),
    ),
  );
}

/// Popular Destinations, the places the province marks popular that the deck
/// above is not already showing, as one block of photos on a card (doc 01:
/// give the top item real size). See All is the way to the rest.
///
/// When every popular place is already in the deck there is nothing new to
/// show, so the section steps aside. With nothing popular at all it keeps
/// its heading and says so, so a new province's Explore still shows where
/// things will go.
class PopularSection extends ConsumerWidget {
  const PopularSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final popular = ref.watch(popularBeyondFeaturedProvider);
    final anyPopular = ref.watch(
      popularDestinationsProvider.select((all) => all.value?.isNotEmpty),
    );
    if (anyPopular == true && popular.value?.isEmpty == true) {
      return const SizedBox.shrink();
    }
    return _FeedSection(
      title: "Popular Destinations",
      onSeeAll: () => context.push(Routes.popular),
      child: popular.whenLocalFirst(
        loading: () => const SectionCard(
          child: AspectRatio(
            aspectRatio: 1 / _Bento.heightShare,
            child: ImagePlaceholder(borderRadius: AppRadii.smAll),
          ),
        ),
        // Popular's own query. The featured cards above say when theirs
        // fails; the rails below hide on theirs.
        error: (error, _) => QuietNote(
          errorCopy("Couldn't load destinations.", error),
          onRetry: () => ref.invalidate(popularDestinationsProvider),
        ),
        data: (items) => items.isEmpty
            ? const QuietNote("Nothing here yet.")
            : SectionCard(child: _Bento(items: items.take(3).toList())),
      ),
    );
  }
}

/// The block, shaped by how many places it has: one fills the card wide,
/// two share it, three are a tall tile with two stacked beside it. Only a
/// tile with room for them carries the town, the tags and the heart; a small
/// one is the photo and the name, which may take two lines.
class _Bento extends StatelessWidget {
  const _Bento({required this.items});

  final List<Destination> items;

  /// The three-place block's height as a share of its width: tall enough
  /// that a small tile holds a two-line name under its photo's top half.
  static const heightShare = 0.7;
  static const _bigShare = 0.58;
  static const _gap = AppSpace.x2;

  /// The section says popular; its photos do not say it again.
  static const _hide = {PlaceTag.popular};

  @override
  Widget build(BuildContext context) {
    if (items.length == 1) {
      return PlacePhoto(
        place: items.single,
        from: HeroSource.popular,
        aspectRatio: 16 / 10,
        dense: false,
        town: true,
        hide: _hide,
        heart: true,
      );
    }
    if (items.length == 2) {
      return Row(
        children: [
          for (final (index, place) in items.indexed) ...[
            if (index > 0) const SizedBox(width: _gap),
            Expanded(
              child: PlacePhoto(
                place: place,
                from: HeroSource.popular,
                aspectRatio: 4 / 5,
                town: true,
                hide: _hide,
                heart: true,
              ),
            ),
          ],
        ],
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = width * heightShare;
        final bigWidth = (width - _gap) * _bigShare;
        final sideWidth = width - _gap - bigWidth;
        final sideHeight = (height - _gap) / 2;
        return SizedBox(
          height: height,
          child: Row(
            children: [
              SizedBox(
                width: bigWidth,
                child: PlacePhoto(
                  place: items.first,
                  from: HeroSource.popular,
                  aspectRatio: bigWidth / height,
                  town: true,
                  hide: _hide,
                  heart: true,
                ),
              ),
              const SizedBox(width: _gap),
              SizedBox(
                width: sideWidth,
                child: Column(
                  children: [
                    for (final (index, place) in items.skip(1).indexed) ...[
                      if (index > 0) const SizedBox(height: _gap),
                      PlacePhoto(
                        place: place,
                        from: HeroSource.popular,
                        aspectRatio: sideWidth / sideHeight,
                        tags: false,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// One of the feed's sections: a gap above it, its heading on the gutter,
/// then what it shows, on the gutter too unless it runs edge to edge (a
/// rail of posters). Each brings its own gap, so one that is not there
/// leaves none.
class _FeedSection extends StatelessWidget {
  const _FeedSection({
    required this.title,
    required this.child,
    this.onSeeAll,
    this.edgeToEdge = false,
  });

  final String title;
  final Widget child;
  final VoidCallback? onSeeAll;
  final bool edgeToEdge;

  static const _gutter = EdgeInsets.symmetric(horizontal: AppSpace.gutter);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: AppSpace.section),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: _gutter,
          child: SectionHeading(title, onSeeAll: onSeeAll),
        ),
        const SizedBox(height: AppSpace.near),
        if (edgeToEdge) child else Padding(padding: _gutter, child: child),
      ],
    ),
  );
}

/// The province's own tours, a whole day already planned, as posters running
/// to the screen edges. Not there until there is one.
class ReadyMadeDays extends ConsumerWidget {
  const ReadyMadeDays({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Hidden while loading, when empty and on an error alike: a rail of
    // extras, from the tours, so a failure there leaves nothing missing
    // that the screen needs.
    final tours = ref.watch(tourRailProvider).value ?? const [];
    if (tours.isEmpty) return const SizedBox.shrink();
    return _FeedSection(
      title: "Day Trips",
      edgeToEdge: true,
      child: TourRail(tours: tours),
    );
  }
}

/// The people who know the place (`guides`, from the CMS): the app
/// complements local guides, and this is where it hands you to one. Each is
/// a white card, their initial, the name with the seal when the province
/// accredits them, and the town; a tap calls or emails them. Signed-in
/// only, as the rules require, so the section is not there for a guest.
class LocalGuides extends ConsumerWidget {
  const LocalGuides({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Hidden while loading, when empty and on an error alike, as Day Tours
    // are: extras, from the guides.
    final guides = ref.watch(guidesProvider).value ?? const [];
    if (guides.isEmpty) return const SizedBox.shrink();
    final scaler = MediaQuery.textScalerOf(context);
    final lines =
        scaler.lineHeightOf(AppTypography.titleSmall) +
        scaler.lineHeightOf(AppTypography.secondLine);
    final content = lines > AppSize.rowMediaDense
        ? lines
        : AppSize.rowMediaDense;
    final height = (content + 2 * AppSpace.x3).ceilToDouble();

    return _FeedSection(
      title: "Meet a Guide",
      edgeToEdge: true,
      child: SizedBox(
        height: height,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.gutter),
          itemCount: guides.length,
          separatorBuilder: (_, _) => const SizedBox(width: AppSpace.x2),
          itemBuilder: (context, index) => SizedBox(
            width: AppSize.guideCard,
            child: _GuideCard(guide: guides[index]),
          ),
        ),
      ),
    );
  }
}

class _GuideCard extends ConsumerWidget {
  const _GuideCard({required this.guide});

  final Guide guide;

  /// Call or email them, and say so when the phone cannot.
  ///
  /// The card's second line is what they lead, not how to reach them, so a
  /// failed tap has to hand the contact over itself. A tablet with no dialer,
  /// or a phone with no mail app, is exactly where this used to leave
  /// somebody with a card that did nothing and no number to copy.
  Future<void> _reach(BuildContext context, WidgetRef ref, Uri uri) async {
    // Resolved before the await: a widget like this has no `mounted` to check
    // afterwards.
    final messenger = ScaffoldMessenger.of(context);
    var opened = false;
    try {
      opened = await ref.read(contactLauncherProvider)(uri);
    } catch (_) {
      // No handler for the scheme throws on some platforms rather than
      // answering false. Either way the answer is the same message.
    }
    if (opened) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          "No app here can open that. Reach ${guide.name} at ${guide.contact}.",
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final brand = context.lakbayan;
    final uri = contactUri(guide.contact);
    final name = guide.name.trim();

    return Pressable(
      enabled: uri != null,
      child: Material(
        color: scheme.surfaceContainerLowest,
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.mdAll),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: uri == null
              ? null
              : () => unawaited(_reach(context, ref, uri)),
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.x3),
            child: Row(
              children: [
                // Their initial on an emerald wash, as on Profile.
                ExcludeSemantics(
                  child: Container(
                    width: AppSize.rowMediaDense,
                    height: AppSize.rowMediaDense,
                    alignment: Alignment.center,
                    decoration: ShapeDecoration(
                      color: brand.tint,
                      shape: const CircleBorder(),
                    ),
                    child: Text(
                      name.isEmpty ? "" : name.characters.first.toUpperCase(),
                      style: AppTypography.titleMedium.copyWith(
                        color: brand.textOnLightGreen,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpace.x3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              name,
                              style: AppTypography.titleSmall,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (guide.verified) ...[
                            const SizedBox(width: AppSpace.x1),
                            Icon(
                              AppIcons.verified,
                              size: AppSize.glyphSm,
                              color: brand.textOnLightGreen,
                              semanticLabel: "Verified",
                            ),
                          ],
                        ],
                      ),
                      Text(
                        guide.town,
                        style: AppTypography.secondLine.copyWith(
                          color: scheme.onSurfaceVariant,
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
        ),
      ),
    );
  }
}

/// For the undecided: one white card asking the question, a chevron saying
/// it goes somewhere. The whole card is the way in, as a Settings row is, so
/// Explore keeps no primary button; a tap opens Keep or Skip, and so does a
/// sideways swipe, the gesture the screen behind it is built on.
class SwipeEntry extends StatelessWidget {
  const SwipeEntry({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    void open() => context.push(Routes.swipe);

    return Semantics(
      button: true,
      label: "Open Keep or Skip",
      excludeSemantics: true,
      child: Pressable(
        child: GestureDetector(
          onHorizontalDragEnd: (_) => open(),
          child: Material(
            color: scheme.surfaceContainerLowest,
            shape: const RoundedRectangleBorder(borderRadius: AppRadii.mdAll),
            child: InkWell(
              onTap: open,
              customBorder: const RoundedRectangleBorder(
                borderRadius: AppRadii.mdAll,
              ),
              child: Padding(
                padding: const EdgeInsets.all(AppSpace.x4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        "Haven't found one you like?",
                        style: AppTypography.titleMedium,
                      ),
                    ),
                    const SizedBox(width: AppSpace.x3),
                    Icon(
                      AppIcons.chevron,
                      size: AppSize.glyphMd,
                      color: scheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Every town pegged to one straight rope: a framed photo with its name and
/// the glyphs of its kinds, all the same size and hung at the same height on
/// the page itself, no panel. The photos sway a few degrees against the swipe
/// and swing back on the bouncy spring when it stops: one number, driven by
/// the scroll, that only turns the photos (D-19). A town opens its page, the
/// photo zooming.
class TownRail extends ConsumerStatefulWidget {
  const TownRail({super.key});

  @override
  ConsumerState<TownRail> createState() => _TownRailState();
}

class _TownRailState extends ConsumerState<TownRail>
    with SingleTickerProviderStateMixin {
  /// How far the photos are swung, in radians; zero at rest. It settles on
  /// `arrive`, the bouncy spring, so a photo swings back past upright once,
  /// as a hanging one does, rather than only creeping home.
  late final _sway = SingleMotionController(
    motion: AppMotion.arrive,
    vsync: this,
    initialValue: 0,
  );

  /// Radians of sway per pixel moved in a frame, and the most it ever shows
  /// (about eight degrees): a swipe leans the photos, it does not throw them.
  static const _perPixel = 0.007;
  static const _most = 0.14;

  @override
  void dispose() {
    _sway.dispose();
    super.dispose();
  }

  bool _lean(ScrollNotification note) {
    if (note.depth != 0 ||
        note is! ScrollUpdateNotification ||
        MediaQuery.disableAnimationsOf(context)) {
      return false;
    }
    // Set to the speed of the swipe, then let go: the spring settles it
    // unless the next frame's movement sets it again.
    _sway
      ..value = ((note.scrollDelta ?? 0) * _perPixel).clamp(-_most, _most)
      ..animateTo(0);
    return false;
  }

  @override
  Widget build(BuildContext context) {
    // Hidden while loading, when empty and on an error alike. Its places
    // are every place, a listener apart from Popular's: if only that read
    // fails, the rail goes without a word, and Popular says nothing of it.
    final towns = ref.watch(townsProvider);
    if (towns.isEmpty) return const SizedBox.shrink();
    final brand = context.lakbayan;
    // Brings its own gap, as every section after the deck does.
    return Padding(
      padding: const EdgeInsets.only(top: AppSpace.section),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpace.gutter),
            child: SectionHeading("Towns to See"),
          ),
          SizedBox(
            height: _Hanging.height,
            child: Stack(
              children: [
                // The rope: one straight line across the page, at the height
                // each clip grips it.
                Positioned(
                  left: 0,
                  right: 0,
                  top: _Hanging.ropeY,
                  height: AppStroke.regular,
                  child: ColoredBox(color: brand.cord),
                ),
                NotificationListener<ScrollNotification>(
                  onNotification: _lean,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpace.gutter,
                    ),
                    itemExtent: _Hanging.extent,
                    itemCount: towns.length,
                    itemBuilder: (context, index) =>
                        _Hanging(town: towns[index], sway: _sway),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One town: its clip on the rope, then the photo in its white frame, hanging
/// upright from the clip and leaning with the rail's sway.
class _Hanging extends StatelessWidget {
  const _Hanging({required this.town, required this.sway});

  final Town town;

  /// The rail's sway in radians, the same for every photo.
  final Animation<double> sway;

  /// A rail tile, 5:6 like the deck's cards, and the gap to the next.
  static const width = AppSize.tourTile;
  static const _photo = width * 6 / 5;
  static const extent = width + AppSpace.x3;

  /// Where the rope runs, and the clip that grips it.
  static const ropeY = AppSpace.x2;
  static const _clip = Size(AppSpace.x4, AppSpace.x2);

  /// The white frame round each photo, like a print's.
  static const _frame = AppSpace.x1;

  /// The rope, the clip and photo, and room for the sway below.
  static const height = ropeY + AppSpace.x2 + _photo + AppSpace.x4;

  @override
  Widget build(BuildContext context) {
    final cord = context.lakbayan.cord;
    final card = Theme.of(context).colorScheme.surfaceContainerLowest;
    final inner = concentricRadius(
      parentRadius: AppRadii.md,
      padding: _frame,
      fallback: AppRadii.sm,
    );

    return Align(
      alignment: Alignment.topLeft,
      child: SizedBox(
        width: width,
        child: Padding(
          padding: const EdgeInsets.only(top: ropeY),
          // The clip is the pivot: only the rotation follows the sway, and
          // the photo is built once and painted once, behind its own
          // boundary, so a frame of the sway turns a kept picture.
          child: AnimatedBuilder(
            animation: sway,
            builder: (context, photo) => Transform.rotate(
              angle: -sway.value,
              alignment: Alignment.topCenter,
              child: photo,
            ),
            child: RepaintBoundary(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: _clip.width,
                    height: _clip.height,
                    decoration: BoxDecoration(
                      color: cord,
                      borderRadius: AppRadii.xsAll,
                    ),
                  ),
                  Container(
                    height: _photo,
                    padding: const EdgeInsets.all(_frame),
                    decoration: BoxDecoration(
                      color: card,
                      borderRadius: AppRadii.mdAll,
                    ),
                    child: TownPhoto(
                      town: town,
                      from: HeroSource.towns,
                      radius: inner,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A town as its photo with its name on it, in the headings' face, and the
/// kinds of place it holds as glyphs under it; a tap opens the town's page,
/// the photo zooming. Explore's hanging towns and search's towns.
class TownPhoto extends StatelessWidget {
  const TownPhoto({
    required this.town,
    required this.from,
    this.radius = AppRadii.tile,
    this.onOpen,
    super.key,
  });

  final Town town;
  final HeroSource from;
  final double radius;

  /// Called just before the page opens: search folds away.
  final VoidCallback? onOpen;

  /// How many kinds' glyphs fit under the name.
  static const _kinds = 4;

  @override
  Widget build(BuildContext context) => Pressable(
    child: GestureDetector(
      onTap: () {
        onOpen?.call();
        context.push(Routes.town(town.name, from: from));
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Stack(
          fit: StackFit.expand,
          children: [
            ParentRadius(
              radius: radius,
              child: PhotoHero(
                tag: townHeroTag(town.name, from),
                child: CoverImage(town.cover),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: MediaScrim(
                padding: const EdgeInsets.fromLTRB(
                  AppSpace.x2,
                  AppSpace.x8,
                  AppSpace.x2,
                  AppSpace.x2,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      town.name,
                      style: AppTypography.titleMedium.copyWith(
                        color: Colors.white,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    // What the town has, as pictures of the kinds it holds.
                    const SizedBox(height: AppSpace.x1),
                    ExcludeSemantics(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (final kind in town.byKind.keys.take(_kinds))
                            Padding(
                              padding: const EdgeInsets.only(
                                right: AppSpace.near,
                              ),
                              child: Icon(
                                AppIcons.kind(kind, filled: true),
                                size: AppSize.glyphMd,
                                color: Colors.white,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Places to eat, a rail of photos with the name on each: food is part of
/// the trip, so it has its own row rather than hiding in a filter.
class WhereToEat extends ConsumerWidget {
  const WhereToEat({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Hidden while loading, when empty and on an error alike, as the towns
    // are, and from the same list of every place.
    final food = ref.watch(foodPlacesProvider);
    if (food.isEmpty) return const SizedBox.shrink();
    return _FeedSection(
      title: "Local Eats",
      onSeeAll: () => ref
          .read(homeCategoryProvider.notifier)
          .toggle(DestinationCategory.food),
      child: SectionCard(child: _Food(places: food)),
    );
  }
}

/// Food shaped by how many places there are, so one place reads as chosen
/// rather than as a rail with a gap in it: one fills the card wide, two
/// share it, three or more are a rail of photos wider than the others on
/// Explore, since a place to eat is picked by its photo.
class _Food extends StatelessWidget {
  const _Food({required this.places});

  final List<Destination> places;

  static const _from = HeroSource.whereToEat;

  @override
  Widget build(BuildContext context) {
    if (places.length == 1) {
      return PlacePhoto(
        place: places.single,
        from: _from,
        aspectRatio: 16 / 9,
        dense: false,
        town: true,
        heart: true,
      );
    }
    if (places.length == 2) {
      return Row(
        children: [
          for (final (index, place) in places.indexed) ...[
            if (index > 0) const SizedBox(width: AppSpace.x2),
            Expanded(
              child: PlacePhoto(
                place: place,
                from: _from,
                aspectRatio: 4 / 5,
                town: true,
                heart: true,
              ),
            ),
          ],
        ],
      );
    }
    return _PlaceRail(
      places: places,
      width: AppSize.foodTile,
      aspectRatio: 4 / 5,
      padding: EdgeInsets.zero,
      tile: (place) => PlacePhoto(
        place: place,
        from: _from,
        aspectRatio: 4 / 5,
        town: true,
        heart: true,
      ),
    );
  }
}

/// Places opened before, newest first, as small square photos: the quickest
/// way back to one. Kept on the phone (`recentlyViewed`), so it works
/// offline, and not there until something has been opened.
class RecentlyViewed extends ConsumerWidget {
  const RecentlyViewed({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recent = ref.watch(recentlyViewedDestinationsProvider);
    if (recent.isEmpty) return const SizedBox.shrink();
    return _FeedSection(
      title: "Recently Viewed",
      edgeToEdge: true,
      child: _PlaceRail(
        places: recent,
        width: AppSize.recentTile,
        aspectRatio: 1,
        // Small, and a reminder: the photo and the name are enough.
        tile: (place) => PlacePhoto(
          place: place,
          from: HeroSource.recent,
          aspectRatio: 1,
          tags: false,
        ),
      ),
    );
  }
}

/// The places with exhibits to scan (D-18), what only this app can show
/// there. Not there when no museum has an exhibit ready. Its photos leave
/// out the scan glyph: the heading says it.
class ScanExhibits extends ConsumerWidget {
  const ScanExhibits({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final places = ref.watch(scanPlacesProvider);
    if (places.isEmpty) return const SizedBox.shrink();
    return _FeedSection(
      title: "Scan Exhibits",
      edgeToEdge: true,
      child: _PlaceRail(
        places: places,
        width: AppSize.railTile,
        aspectRatio: 4 / 5,
        tile: (place) => PlacePhoto(
          place: place,
          from: HeroSource.scan,
          aspectRatio: 4 / 5,
          town: true,
          hide: const {PlaceTag.scan},
          heart: true,
        ),
      ),
    );
  }
}

/// A row of place photos exactly one photo tall (STANDARDS 10.4a), every
/// tile the same width, built only as it nears the screen.
class _PlaceRail extends StatelessWidget {
  const _PlaceRail({
    required this.places,
    required this.width,
    required this.aspectRatio,
    required this.tile,
    this.padding = const EdgeInsets.symmetric(horizontal: AppSpace.gutter),
  });

  final List<Destination> places;
  final double width;
  final double aspectRatio;
  final Widget Function(Destination place) tile;

  /// Where the rail starts and ends: the gutter when it runs edge to edge,
  /// none inside a card.
  final EdgeInsets padding;

  static const _gap = AppSpace.x2;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: (width / aspectRatio).ceilToDouble(),
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: padding,
      itemCount: places.length,
      separatorBuilder: (_, _) => const SizedBox(width: _gap),
      itemBuilder: (context, index) =>
          SizedBox(width: width, child: tile(places[index])),
    ),
  );
}
