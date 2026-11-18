import "dart:math" show max, pi;

import "package:animations/animations.dart";
import "package:flutter/material.dart";
import "package:flutter/rendering.dart" show RenderAbstractViewport;
import "package:flutter_map/flutter_map.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "package:latlong2/latlong.dart" hide pi;
import "package:motor/motor.dart";

import "../../../core/errors/error_copy.dart";
import "../../../core/errors/local_first.dart";
import "../../../core/models/destination.dart";
import "../../../core/models/exhibit.dart";
import "../../../core/router/app_router.dart";
import "../../../core/theme/app_dimens.dart";
import "../../../core/theme/app_icons.dart";
import "../../../core/theme/app_motion.dart";
import "../../../core/theme/app_typography.dart";
import "../../../core/theme/lakbayan_colors.dart";
import "../../../core/widgets/chrome/system_bars.dart";
import "../../../core/widgets/content/media_tile.dart";
import "../../../core/widgets/content/page_dots.dart";
import "../../../core/widgets/content/quiet_note.dart";
import "../../../core/widgets/content/section_heading.dart";
import "../../../core/widgets/content/storage_image.dart";
import "../../../core/widgets/controls/bar_item_group.dart";
import "../../../core/widgets/controls/symbol_button.dart";
import "../../../core/widgets/motion/motion.dart";
import "../../../core/widgets/motion/page_transitions.dart";
import "../../ar/domain/ar_providers.dart";
import "../../ar/presentation/exhibits_section.dart";
import "../../audio/presentation/audio_guide_section.dart";
import "../../explore/domain/home_tab.dart";
import "../../itineraries/presentation/add_to_itinerary_sheet.dart";
import "../../maps/domain/tile_source.dart";
import "../../maps/presentation/map_view.dart"
    show Basemap, StillMapCredit, showDirections;
import "../domain/destination_providers.dart";
import "../domain/photo_credit.dart";
import "../domain/place_share.dart";
import "../domain/practical_text.dart";
import "../domain/recently_viewed.dart";
import "photo_credit_label.dart";
import "place_photo.dart";
import "save_heart.dart";

/// Place detail. **Job:** decide whether to go, then put it on a trip.
/// **Emotion:** being there already.
///
/// A clean photo stage under the status bar; the page rises over its foot on
/// a rounded edge. Back, and share with the heart, stay pinned. On the page:
/// the name, then the place one part at a time (D-19): Overview (about, the
/// facts folded under Details, the audio guide, Location, Known For), a
/// museum's Exhibits (D-18), Photos and Nearby. Floating: Add to Trip. Only
/// name, town, description and coordinates are required in the CMS; any
/// other part is simply absent when empty, and free text is only tidied.
class DestinationDetailScreen extends ConsumerStatefulWidget {
  const DestinationDetailScreen({required this.id, this.from, super.key});

  final String id;

  /// The surface the cover flew from; null for a deep link.
  final HeroSource? from;

  @override
  ConsumerState<DestinationDetailScreen> createState() =>
      _DestinationDetailScreenState();
}

class _DestinationDetailScreenState
    extends ConsumerState<DestinationDetailScreen> {
  @override
  void initState() {
    super.initState();
    // Opening a place is what "recently viewed" means. Once, not per build,
    // and after the first frame: a provider must not change mid-build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(recentlyViewedProvider.notifier).markViewed(widget.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final destination = ref.watch(destinationByIdProvider(widget.id));
    return destination.whenLocalFirst(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => MessageScreen(
        errorCopy("Couldn't load this destination.", e),
        onRetry: () => ref.invalidate(destinationByIdProvider(widget.id)),
      ),
      data: (d) => d == null
          ? const MessageScreen("This destination is no longer available.")
          : Scaffold(
              body: _PinnedActionScope(
                child: EntranceScope(
                  child: _Content(destination: d, from: widget.from),
                ),
              ),
            ),
    );
  }
}

class _Content extends StatefulWidget {
  const _Content({required this.destination, required this.from});

  final Destination destination;
  final HeroSource? from;

  @override
  State<_Content> createState() => _ContentState();
}

class _ContentState extends State<_Content> {
  /// Read by the photo's drift and by the pinned controls' change of
  /// surface; neither rebuilds the page.
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final destination = widget.destination;
    final actionHeight = _PinnedAction.extentOf(context);
    final topInset = MediaQuery.viewPaddingOf(context).top;
    final stage = _PhotoStage.heightOf(context);
    final controlsTop = topInset + AppSpace.x2;
    // The page's edge reaches the controls' foot: from here they sit on the
    // white page rather than on the photo.
    final groundAt =
        stage - _PhotoStage.edge - controlsTop - AppSize.minTouchTarget;

    return Stack(
      children: [
        CustomScrollView(
          controller: _scroll,
          slivers: [
            SliverToBoxAdapter(
              child: _PhotoStage(
                destination: destination,
                from: widget.from,
                scroll: _scroll,
                height: stage,
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                AppSpace.gutter,
                0,
                AppSpace.gutter,
                actionHeight + AppSpace.section,
              ),
              // The page arrives under the photo in reading order.
              sliver: SliverList.list(
                children: [
                  Entrance(child: _Title(destination: destination)),
                  Entrance(
                    order: 1,
                    child: _Parts(
                      destination: destination,
                      scroll: _scroll,
                      clearance: controlsTop + AppSize.minTouchTarget,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        // The photo keeps the status bar at rest; the page's white closes
        // in under it as the name arrives there.
        StatusBarGround.below(scroll: _scroll, contentTop: stage),
        Positioned(
          top: controlsTop,
          left: AppSpace.x2,
          right: AppSpace.x2,
          child: _PinnedControls(
            destination: destination,
            scroll: _scroll,
            groundAt: groundAt,
          ),
        ),
        _PinnedAction(
          label: "Add to Trip",
          icon: AppIcons.add,
          onPressed: () => showAddToItinerary(
            context,
            destinationId: destination.id,
            destinationName: destination.name,
          ),
        ),
      ],
    );
  }
}

/// The photos, clean and pageable when there are several; a tap opens the
/// one showing full screen. The page's rounded edge sits over their foot,
/// carrying the dots, so the page reads as rising over the photo. As the page
/// scrolls up over it, the photo drifts at half speed. The photo showing
/// carries its credit, where one was recorded (`photoCreditLine`).
class _PhotoStage extends StatefulWidget {
  const _PhotoStage({
    required this.destination,
    required this.from,
    required this.scroll,
    required this.height,
  });

  final Destination destination;
  final HeroSource? from;
  final ScrollController scroll;
  final double height;

  /// The page's rounded edge over the photo's foot.
  static const edge = AppSpace.x6;

  /// About a third of the screen goes to the photo, leaving the name and the
  /// parts in view under it.
  static const _share = 0.34;

  /// Never shorter than the route map's header, so a small phone still gets
  /// a photo rather than a strip.
  static double heightOf(BuildContext context) {
    final screen = MediaQuery.sizeOf(context).height;
    final top = MediaQuery.viewPaddingOf(context).top;
    return max(screen * _share, top + AppSize.routePreview).ceilToDouble();
  }

  @override
  State<_PhotoStage> createState() => _PhotoStageState();
}

class _PhotoStageState extends State<_PhotoStage> {
  final _pages = PageController();
  int _page = 0;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final destination = widget.destination;
    final images = destination.images;
    final from = widget.from;
    final scheme = Theme.of(context).colorScheme;
    final credit = _page < images.length
        ? photoCreditLine(destination.creditFor(images[_page]))
        : null;

    final Widget photos = images.isEmpty
        ? const ImagePlaceholder(borderRadius: BorderRadius.zero)
        : PageView.builder(
            controller: _pages,
            onPageChanged: (i) => setState(() => _page = i),
            itemCount: images.length,
            itemBuilder: (context, i) {
              // The cover keeps the tag of the tile that opened this page,
              // so back still shrinks it home; the rest take the stage's own.
              final tag = i == 0 && from != null
                  ? coverHeroTag(destination.id, from)
                  : stageHeroTag(destination.id, i);
              // A tap opens the photo full screen, zooming from here: the
              // same viewer as the Photos part.
              return Semantics(
                button: true,
                label: "View photo ${i + 1} of ${images.length}",
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => context.push(
                    Routes.photos(
                      destination.id,
                      at: i,
                      stage: true,
                      tag: from == null
                          ? null
                          : coverHeroTag(destination.id, from),
                    ),
                    extra: (int index) {
                      if (mounted && _pages.hasClients) {
                        _pages.jumpToPage(index);
                      }
                    },
                  ),
                  child: PhotoHero(
                    tag: tag,
                    child: StorageImage(path: images[i]),
                  ),
                ),
              );
            },
          );

    return SizedBox(
      height: widget.height,
      // The drifting photo stays inside its stage.
      child: ClipRect(
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (MediaQuery.disableAnimationsOf(context))
              photos
            else
              _Drift(scroll: widget.scroll, child: photos),
            // Light status bar icons over the photo only: once the page's
            // paper edge is under the status bar, the icons turn dark.
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              bottom: _PhotoStage.edge,
              child: SystemBars(overPhoto: true, child: SizedBox.expand()),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: _PhotoStage.edge + AppSpace.x3,
              child: PageDots(
                count: images.length,
                current: _page,
                onPhoto: true,
              ),
            ),
            // The credit of the photo showing, at its foot's trailing corner,
            // where the map keeps its own. Over the dots when there are any,
            // rather than beside them: a long credit would reach them.
            if (credit != null)
              Positioned(
                left: AppSpace.x2,
                right: AppSpace.x2,
                bottom:
                    _PhotoStage.edge +
                    (images.length > 1
                        ? AppSpace.x3 + AppSize.pageDot + AppSpace.x2
                        : AppSpace.x2),
                child: Align(
                  alignment: Alignment.bottomRight,
                  child: FadeSwap(
                    id: credit,
                    alignment: Alignment.bottomRight,
                    child: PhotoCreditLabel(credit, onPhoto: true),
                  ),
                ),
              ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: _PhotoStage.edge,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: scheme.surface,
                  borderRadius: AppRadii.sheetTop,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Photo drifts at half the page's scroll speed: a translation read from the
/// scroll offset, photo built once so a scroll repaints without rebuilding.
class _Drift extends StatelessWidget {
  const _Drift({required this.scroll, required this.child});

  final ScrollController scroll;
  final Widget child;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: scroll,
    child: child,
    builder: (context, child) {
      final offset = scroll.hasClients && scroll.offset > 0
          ? scroll.offset
          : 0.0;
      return Transform.translate(offset: Offset(0, offset / 2), child: child);
    },
  );
}

/// Between the blocks of a part: a clear step, kept short (D-19).
const _gap = AppSpace.x3;

/// The name, large, and at its trailing end what the place is, as glyphs on
/// small white circles, the way a photo's tags sit: its kind (the CMS's finer
/// kind when it has one, "Cave", is the glyph's tooltip and spoken label),
/// and the flame when the province marks it popular. Each says its word on
/// a long press and to a screen reader. Nothing the page says again: the
/// town is on the Location card, the fee in Details, the exhibits are their
/// own part.
class _Title extends StatelessWidget {
  const _Title({required this.destination});

  final Destination destination;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final place = destination;
    final kind = place.subcategory?.trim();
    final facts = [
      if (place.category != DestinationCategory.unknown)
        (
          glyph: AppIcons.kind(place.category),
          word: kind == null || kind.isEmpty
              ? _kindName(place.category)
              : capital(kind),
        ),
      if (place.popular) (glyph: AppIcons.popular, word: "Popular"),
    ];
    // Level with the name's first line, however large the type is.
    final firstLine = MediaQuery.textScalerOf(context)
        .lineHeightOf(AppTypography.hero);
    final lift = ((firstLine - AppSize.tileSave) / 2).clamp(0.0, firstLine);

    return Padding(
      padding: const EdgeInsets.only(top: AppSpace.x2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(place.name, style: AppTypography.hero),
            ),
          ),
          for (final (:glyph, :word) in facts)
            Padding(
              padding: EdgeInsetsDirectional.only(
                start: AppSpace.x1,
                top: lift,
              ),
              child: Tooltip(
                message: word,
                excludeFromSemantics: true,
                child: Semantics(
                  label: word,
                  excludeSemantics: true,
                  child: Container(
                    width: AppSize.tileSave,
                    height: AppSize.tileSave,
                    alignment: Alignment.center,
                    decoration: ShapeDecoration(
                      color: scheme.surfaceContainerLowest,
                      shape: const CircleBorder(),
                    ),
                    child: Icon(
                      glyph,
                      size: AppSize.glyphSm,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A kind as one of it ("Church"), for the line under a place's name; the
/// kinds' own labels are the plural headings of their lists.
String _kindName(DestinationCategory kind) => switch (kind) {
  DestinationCategory.church => "Church",
  DestinationCategory.nature => "Nature",
  DestinationCategory.heritage => "Heritage",
  DestinationCategory.museum => "Museum",
  DestinationCategory.food => "Food",
  DestinationCategory.landmark => "Landmark",
  DestinationCategory.unknown => "",
};

/// Back alone on its circle at the leading top; share and the heart on one
/// glass capsule at the trailing top (PREFERENCES: symbols over a photo
/// share one capsule, back stays alone). Pinned, so back is always one tap
/// away. Once the page is under them they ease from glass to the card, as a
/// control on the page is (`SymbolButton.onGround`): once, on the chrome
/// spring, when the page crosses them, not on every scroll frame.
class _PinnedControls extends ConsumerStatefulWidget {
  const _PinnedControls({
    required this.destination,
    required this.scroll,
    required this.groundAt,
  });

  final Destination destination;
  final ScrollController scroll;

  /// The scroll offset at which the page's edge reaches the controls.
  final double groundAt;

  @override
  ConsumerState<_PinnedControls> createState() => _PinnedControlsState();
}

class _PinnedControlsState extends ConsumerState<_PinnedControls> {
  bool _onGround = false;

  @override
  void initState() {
    super.initState();
    widget.scroll.addListener(_check);
  }

  @override
  void didUpdateWidget(_PinnedControls old) {
    super.didUpdateWidget(old);
    if (old.scroll != widget.scroll) {
      old.scroll.removeListener(_check);
      widget.scroll.addListener(_check);
    }
    _check();
  }

  @override
  void dispose() {
    widget.scroll.removeListener(_check);
    super.dispose();
  }

  void _check() {
    final scroll = widget.scroll;
    final onGround = scroll.hasClients && scroll.offset > widget.groundAt;
    if (onGround != _onGround) setState(() => _onGround = onGround);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final id = widget.destination.id;
    return AppMotionBuilder(
      end: _onGround ? 1 : 0,
      builder: (context, t, _) {
        final tone = Color.lerp(
          context.lakbayan.glass,
          scheme.surfaceContainerLowest,
          t.clamp(0.0, 1.0),
        )!;
        return Row(
          children: [
            SymbolButton(
              icon: AppIcons.back,
              tooltip: "Back",
              onTap: context.popOrHome,
              background: tone,
            ),
            const Spacer(),
            BarItemGroup.overMedia(
              background: tone,
              items: [
                BarItem(
                  icon: AppIcons.share,
                  tooltip: "Share",
                  onPressed: () => sharePlace(context, ref, widget.destination),
                ),
                BarItem.control(SaveHeart(id, style: SaveHeartStyle.bar)),
              ],
            ),
          ],
        );
      },
    );
  }
}

/// The place as text, to the phone's share sheet (`placeShareText`), and a
/// word when the sheet will not open. Closing it unshared says nothing. The
/// page's controls and the photo viewer's.
Future<void> sharePlace(
  BuildContext context,
  WidgetRef ref,
  Destination place,
) async {
  // Resolved before the await, which the sheet holds open until it closes.
  final messenger = ScaffoldMessenger.of(context);
  try {
    await ref.read(textSharerProvider)(
      placeShareText(place),
      subject: placeShareSubject(place),
    );
  } catch (e) {
    // Logged, because the snackbar reads the same for a bug as for a phone
    // with no share sheet.
    debugPrint("Share failed: $e");
    messenger.showSnackBar(
      const SnackBar(
        content: Text("Couldn't open sharing on this device."),
        duration: Duration(seconds: 2),
      ),
    );
  }
}

/// A tag in Title Case, the small words left small: "Bats at Dusk".
String _titleCase(String text) => [
  for (final (i, word) in text.trim().split(RegExp(r"\s+")).indexed)
    i > 0 && _smallWords.contains(word.toLowerCase())
        ? word.toLowerCase()
        : capital(word),
].join(" ");

final _smallWords = "a an and at by for in of on or the to with".split(" ");

/// The page's parts. Each is there only when it has something to show.
enum _Part {
  overview("Overview"),
  exhibits("Exhibits"),
  photos("Photos"),
  nearby("Nearby");

  const _Part(this.label);
  final String label;
}

/// The place one part at a time (D-19): a museum's Exhibits, Photos and
/// Nearby beside the Overview, so a new kind of content is a new part, not
/// more scroll. The pill travels to the chosen part and its content slides
/// in from that side (the `animations` shared axis, inside the page); a
/// fling across the content moves one part.
///
/// A part is never shorter than the screen under the switcher, and choosing
/// one while scrolled past the switcher scrolls back to it, on the spring,
/// while the old part is still there. So the page never ends above where it
/// is scrolled to. When it did (scrolled down Overview, then Photos), the
/// scroll was corrected to the shorter end without telling its listeners,
/// and the status bar's ground and the pinned controls stayed where the old
/// scroll had put them: a white band over the photo.
class _Parts extends ConsumerStatefulWidget {
  const _Parts({
    required this.destination,
    required this.scroll,
    required this.clearance,
  });

  final Destination destination;

  /// The page's scroll, to bring the switcher back into view.
  final ScrollController scroll;

  /// How far down the screen the pinned controls reach: the switcher comes
  /// to rest just under them.
  final double clearance;

  @override
  ConsumerState<_Parts> createState() => _PartsState();
}

class _PartsState extends ConsumerState<_Parts> {
  _Part _part = _Part.overview;
  bool _forward = true;

  void _go(List<_Part> parts, int index) {
    if (index < 0 || index >= parts.length || parts[index] == _part) return;
    setState(() {
      _forward = index > parts.indexOf(_part);
      _part = parts[index];
    });
    _keepSwitcherInView();
  }

  /// Scrolled past the switcher, back up to it, so the new part starts at
  /// its top; a move the scroll's listeners hear, unlike a correction.
  void _keepSwitcherInView() {
    final scroll = widget.scroll;
    final box = context.findRenderObject();
    if (!scroll.hasClients || box == null) return;
    final top =
        RenderAbstractViewport.of(box).getOffsetToReveal(box, 0).offset -
        widget.clearance;
    if (scroll.offset <= top) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      scroll.jumpTo(top);
    } else {
      scroll.animateTo(
        top,
        duration: AppMotion.span,
        curve: SpringCurve(AppMotion.chrome, AppMotion.span),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final place = widget.destination;
    final exhibits = place.hasAR
        ? ref.watch(destinationExhibitsProvider(place.id)).value ?? const []
        : const <Exhibit>[];
    final nearby = ref.watch(aroundHereProvider(place.id));
    final parts = [
      _Part.overview,
      if (exhibits.isNotEmpty) _Part.exhibits,
      if (place.images.isNotEmpty) _Part.photos,
      if (nearby.isNotEmpty) _Part.nearby,
    ];
    final part = parts.contains(_part) ? _part : _Part.overview;
    final index = parts.indexOf(part);
    final content = switch (part) {
      _Part.overview => _Overview(destination: place),
      _Part.exhibits => ExhibitsSection(destination: place),
      _Part.photos => _Photos(destination: place),
      _Part.nearby => _Nearby(places: nearby),
    };
    final reduced = MediaQuery.disableAnimationsOf(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (parts.length > 1) ...[
          const SizedBox(height: _gap),
          _Segments(
            labels: [for (final each in parts) each.label],
            index: index,
            onSelected: (chosen) => _go(parts, chosen),
          ),
        ],
        const SizedBox(height: _gap),
        GestureDetector(
          onHorizontalDragEnd: (details) {
            final speed = details.primaryVelocity ?? 0;
            if (speed.abs() < AppMotion.flingSpeed) return;
            _go(parts, index + (speed < 0 ? 1 : -1));
          },
          child: ConstrainedBox(
            // At least the screen under the switcher once it sits under
            // the pinned controls (see the class comment).
            constraints: BoxConstraints(
              minHeight: max(
                0,
                MediaQuery.sizeOf(context).height -
                    widget.clearance -
                    2 * _gap -
                    AppSize.minTouchTarget,
              ),
            ),
            child: PageTransitionSwitcher(
              reverse: !_forward,
              duration: AppMotion.span,
              layoutBuilder: (entries) =>
                  Stack(alignment: Alignment.topCenter, children: entries),
              transitionBuilder: (child, animation, secondary) => reduced
                  ? FadeTransition(opacity: animation, child: child)
                  : SharedAxisTransition(
                      animation: animation,
                      secondaryAnimation: secondary,
                      transitionType: SharedAxisTransitionType.horizontal,
                      fillColor: Theme.of(context).colorScheme.surface,
                      child: child,
                    ),
              child: KeyedSubtree(key: ValueKey(part), child: content),
            ),
          ),
        ),
      ],
    );
  }
}

/// The parts as one white card, the chosen one on an emerald shape that
/// travels to it on the chrome spring: painted, never rebuilt per frame.
/// The card takes the page's card radius, as Details and the audio guide
/// do, and the shape inside is concentric with it, so the page's blocks
/// share one curvature rather than a capsule among cards. Each part is a
/// full-height target.
class _Segments extends StatefulWidget {
  const _Segments({
    required this.labels,
    required this.index,
    required this.onSelected,
  });

  final List<String> labels;
  final int index;
  final ValueChanged<int> onSelected;

  @override
  State<_Segments> createState() => _SegmentsState();
}

class _SegmentsState extends State<_Segments>
    with SingleTickerProviderStateMixin {
  /// The gap from the card's edge to the chosen part's shape, and that
  /// shape's corners, derived from the card's (never typed).
  static const _inset = AppSpace.x1;
  static final _inner = concentricRadius(
    parentRadius: AppRadii.md,
    padding: _inset,
    fallback: AppRadii.sm,
  );

  late final _at = SingleMotionController(
    motion: AppMotion.chrome,
    vsync: this,
    initialValue: widget.index.toDouble(),
  );

  @override
  void didUpdateWidget(_Segments old) {
    super.didUpdateWidget(old);
    if (widget.index == old.index) return;
    final to = widget.index.toDouble();
    if (MediaQuery.disableAnimationsOf(context)) {
      _at.value = to;
    } else {
      _at.animateTo(to);
    }
  }

  @override
  void dispose() {
    _at.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final labels = widget.labels;
    final inner = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(_inner),
    );
    return Material(
      color: scheme.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(borderRadius: AppRadii.mdAll),
      child: SizedBox(
        height: AppSize.minTouchTarget,
        child: CustomPaint(
          painter: TravellingPill(
            moves: _at,
            at: (size) {
              final cell = size.width / labels.length;
              return Rect.fromLTWH(
                _at.value * cell,
                0,
                cell,
                size.height,
              ).deflate(_inset);
            },
            color: scheme.primary,
            radius: _inner,
          ),
          child: Row(
            children: [
              for (final (index, label) in labels.indexed)
                Expanded(
                  child: Semantics(
                    selected: index == widget.index,
                    button: true,
                    child: InkWell(
                      customBorder: inner,
                      onTap: () => widget.onSelected(index),
                      child: Center(
                        child: AnimatedDefaultTextStyle(
                          duration: AppMotion.edge,
                          style: AppTypography.labelMedium.copyWith(
                            color: index == widget.index
                                ? scheme.onPrimary
                                : scheme.onSurfaceVariant,
                          ),
                          child: Text(label, maxLines: 1),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The place at a glance: what it is, the facts folded under Details, the
/// audio guide, where it is, and what it is known for.
class _Overview extends StatelessWidget {
  const _Overview({required this.destination});

  final Destination destination;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _About(destination: destination),
      _Details(destination: destination),
      _AudioGuide(id: destination.id, cover: destination.coverImage),
      _Location(destination: destination),
      _KnownFor(destination: destination),
    ],
  );
}

/// The description, a little heavier, running into the history as one
/// paragraph, cut at three lines. Read More grows it open in place on the
/// chrome spring and Show Less folds it back; under reduced motion the two
/// cross-fade. No button when it fits.
class _About extends StatefulWidget {
  const _About({required this.destination});

  final Destination destination;

  @override
  State<_About> createState() => _AboutState();
}

class _AboutState extends State<_About> {
  bool _open = false;

  static const _lines = 3;
  static final _spring = SpringCurve(AppMotion.chrome, AppMotion.span);

  @override
  Widget build(BuildContext context) {
    final lead = widget.destination.description.trim();
    final rest = widget.destination.history?.trim() ?? "";
    if (lead.isEmpty && rest.isEmpty) return const SizedBox.shrink();
    final span = TextSpan(
      style: AppTypography.bodyLarge,
      children: [
        if (lead.isNotEmpty)
          TextSpan(
            text: lead,
            style: AppTypography.titleSmall.copyWith(
              height: AppTypography.bodyLarge.height,
            ),
          ),
        if (lead.isNotEmpty && rest.isNotEmpty) const TextSpan(text: " "),
        if (rest.isNotEmpty) TextSpan(text: rest),
      ],
    );

    return LayoutBuilder(
      builder: (context, box) {
        final measure = TextPainter(
          text: span,
          maxLines: _lines,
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout(maxWidth: box.maxWidth);
        final long = measure.didExceedMaxLines;
        measure.dispose();
        final text = Text.rich(
          span,
          maxLines: _open ? null : _lines,
          overflow: _open ? null : TextOverflow.ellipsis,
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (MediaQuery.disableAnimationsOf(context))
              FadeSwap(id: _open, alignment: Alignment.topLeft, child: text)
            else
              AnimatedSize(
                duration: AppMotion.span,
                curve: _spring,
                alignment: Alignment.topCenter,
                child: text,
              ),
            if (long)
              TextButton(
                onPressed: () => setState(() => _open = !_open),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  textStyle: AppTypography.labelMedium,
                ),
                child: FadeSwap(
                  id: _open,
                  alignment: Alignment.centerLeft,
                  child: Text(_open ? "Show Less" : "Read More"),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// The practical facts, folded under Details: a tap unfolds them in place,
/// the chevron turning. Each is its name small, its value, and the rest of
/// the editor's sentence on a quieter line. Not there when the CMS has none.
class _Details extends StatefulWidget {
  const _Details({required this.destination});

  final Destination destination;

  @override
  State<_Details> createState() => _DetailsState();
}

class _DetailsState extends State<_Details> {
  bool _open = false;

  /// Tenths of the row the fact's name takes; its value takes the rest.
  static const _labelShare = 4;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final practical = widget.destination.practical;
    final facts = [
      for (final (label, raw) in [
        ("Hours", practical?.openHours),
        ("Entry", practical?.entryFee),
        ("Best Season", practical?.bestSeason),
        ("Accessibility", practical?.accessibility),
      ])
        if (tidyFact(raw) case final fact?) (label: label, fact: fact),
    ];
    if (facts.isEmpty) return const SizedBox.shrink();
    final quiet = scheme.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.only(top: _gap),
      child: Material(
        color: scheme.surfaceContainerLowest,
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.mdAll),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              button: true,
              expanded: _open,
              child: InkWell(
                onTap: () => setState(() => _open = !_open),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpace.x4,
                    AppSpace.x3,
                    AppSpace.x3,
                    AppSpace.x3,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text("Details", style: AppTypography.titleSmall),
                      ),
                      AppMotionBuilder(
                        end: _open ? 1 : 0,
                        child: Icon(
                          AppIcons.chevronDown,
                          size: AppSize.glyphMd,
                          color: quiet,
                        ),
                        builder: (context, t, chevron) =>
                            Transform.rotate(angle: t * pi, child: chevron),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Fold(
              open: _open,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpace.x4,
                  AppSpace.x1,
                  AppSpace.x4,
                  AppSpace.x4,
                ),
                // A fold loosens its child's width, so the column is told to
                // take all of it or it shrinks to its widest line, centred.
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final (index, (:label, :fact)) in facts.indexed)
                      Padding(
                        padding: EdgeInsets.only(
                          top: index == 0 ? 0 : AppSpace.x3,
                        ),
                        child: MergeSemantics(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: _labelShare,
                                child: Text(
                                  label,
                                  style: AppTypography.labelMedium.copyWith(
                                    color: quiet,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 10 - _labelShare,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      fact.value,
                                      style: AppTypography.titleSmall,
                                    ),
                                    if (fact.note case final note?)
                                      Text(
                                        note,
                                        style: AppTypography.secondLine
                                            .copyWith(color: quiet),
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
          ],
        ),
      ),
    );
  }
}

/// Where it is: a small still map with its pin (a tap shows it on the Map
/// tab), its town, which opens the town's page, and Directions, the turn
/// arrow on an emerald circle, to the phone's map app.
class _Location extends StatelessWidget {
  const _Location({required this.destination});

  final Destination destination;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: _gap),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeading("Location"),
        Material(
          color: Theme.of(context).colorScheme.surfaceContainerLowest,
          shape: const RoundedRectangleBorder(borderRadius: AppRadii.mdAll),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _StillMap(destination: destination),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => context.push(Routes.town(destination.town)),
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpace.x4),
                        child: Text(
                          destination.town,
                          style: AppTypography.titleSmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(AppSpace.x2),
                    child: SymbolButton(
                      icon: AppIcons.directions,
                      tooltip: "Directions",
                      background: Theme.of(context).colorScheme.primary,
                      color: Theme.of(context).colorScheme.onPrimary,
                      onTap: () => showDirections(context, destination),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

/// The place's pin on a map that does not move; a tap shows it on the Map
/// tab.
class _StillMap extends ConsumerWidget {
  const _StillMap({required this.destination});

  final Destination destination;

  /// Close enough to read the place's surroundings.
  static const _zoom = 14.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final source = ref.watch(tileSourceProvider);
    final at = LatLng(destination.coords.lat, destination.coords.lng);
    final pin = ShapeDecoration(
      color: scheme.primary,
      shape: CircleBorder(
        side: BorderSide(
          color: scheme.surfaceContainerLowest,
          width: AppStroke.bold,
        ),
      ),
    );

    void onTheMap() {
      ref.read(mapSelectedIdProvider.notifier).select(destination.id);
      ref.read(browseShowsGridProvider.notifier).set(false);
      ref.read(selectedHomeTabProvider.notifier).select(HomeTab.map);
      context.go(Routes.home);
    }

    return SizedBox(
      height: AppSize.mapCard,
      child: Stack(
        fit: StackFit.expand,
        children: [
          RepaintBoundary(
            child: IgnorePointer(
              child: FlutterMap(
                options: MapOptions(
                  initialCenter: at,
                  initialZoom: _zoom,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.none,
                  ),
                ),
                children: [
                  Basemap(source: source),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: at,
                        width: AppSpace.x5,
                        height: AppSpace.x5,
                        child: DecoratedBox(decoration: pin),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          StillMapCredit(source: source),
          Semantics(
            button: true,
            label: "Show ${destination.name} on the map",
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(onTap: onTheMap),
            ),
          ),
        ],
      ),
    );
  }
}

/// What the place is known for: the CMS's tags in Title Case, each on its
/// own paper tag at its natural width inside one white card, wrapping as
/// they fit. A two-column grid of words left ragged gaps beside the short
/// ones. No glyph per tag: the tags are the editor's free words ("Bats at
/// Dusk"), and a glyph for each would be a guess, or the same one repeated
/// as a bullet. Not there when it has none.
class _KnownFor extends StatelessWidget {
  const _KnownFor({required this.destination});

  final Destination destination;

  /// The card's inset to the first tags, and their corners from the card's.
  static final _tagRadius = concentricRadius(
    parentRadius: AppRadii.md,
    padding: AppSpace.x3,
    fallback: AppRadii.sm,
  );

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tags = [
      for (final tag in destination.tags)
        if (tag.trim().isNotEmpty) _titleCase(tag),
    ];
    if (tags.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: _gap),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionHeading("Known For"),
          Material(
            color: scheme.surfaceContainerLowest,
            shape: const RoundedRectangleBorder(borderRadius: AppRadii.mdAll),
            child: Padding(
              padding: const EdgeInsets.all(AppSpace.x3),
              child: Wrap(
                spacing: AppSpace.x2,
                runSpacing: AppSpace.x2,
                children: [
                  for (final tag in tags)
                    // Paper inside the white card (never grey on grey), its
                    // corners concentric with the card's.
                    DecoratedBox(
                      decoration: ShapeDecoration(
                        color: scheme.surfaceContainerLow,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(_tagRadius),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpace.x3,
                          vertical: AppSpace.x2,
                        ),
                        child: Text(tag, style: AppTypography.labelMedium),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A handful of square photos in rows inside the page's own scroll, so a
/// grid that sizes to them is the plain choice (STANDARDS 3.4).
class _Grid extends StatelessWidget {
  const _Grid({
    required this.columns,
    required this.gap,
    required this.children,
  });

  final int columns;
  final double gap;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => GridView.count(
    crossAxisCount: columns,
    mainAxisSpacing: gap,
    crossAxisSpacing: gap,
    shrinkWrap: true,
    padding: EdgeInsets.zero,
    physics: const NeverScrollableScrollPhysics(),
    children: children,
  );
}

/// Every photo of the place, three to a row; one opens the viewer, the
/// photo zooming.
class _Photos extends StatelessWidget {
  const _Photos({required this.destination});

  final Destination destination;

  @override
  Widget build(BuildContext context) {
    final id = destination.id;
    final images = destination.images;
    return _Grid(
      columns: 3,
      gap: AppSpace.x1,
      children: [
        for (final (index, path) in images.indexed)
          MediaTile(
            media: PhotoHero(
              tag: photoHeroTag(id, index),
              child: StorageImage(path: path),
            ),
            aspectRatio: 1,
            radius: AppRadii.sm,
            onTap: () => context.push(Routes.photos(id, at: index)),
          ),
      ],
    );
  }
}

/// The nearest places, each with how far on its photo, then more from the
/// town; a photo opens its page.
class _Nearby extends StatelessWidget {
  const _Nearby({required this.places});

  final List<AroundHerePlace> places;

  @override
  Widget build(BuildContext context) => _Grid(
    columns: 2,
    gap: AppSpace.x2,
    children: [
      // How far is what this part is about, so it is the photo's one note.
      for (final (:place, :distance) in places)
        PlacePhoto(
          place: place,
          from: HeroSource.around,
          aspectRatio: 1,
          radius: AppRadii.md,
          tags: false,
          pill: distance == null ? null : PhotoPill(distance),
        ),
    ],
  );
}

/// The audio guide as one card: listening is what the app is for once you
/// are there. Absent entirely when the place has no stops.
///
/// Unlike the page's optional parts it does not simply vanish while it is
/// not ready: until the stops arrive, a quiet card holds its place, and if
/// they cannot be read, it says so and offers another try. Stops already on
/// the phone are shown even when a later read fails.
class _AudioGuide extends ConsumerWidget {
  const _AudioGuide({required this.id, required this.cover});

  final String id;
  final String? cover;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Widget? guide = ref
        .watch(destinationSegmentsProvider(id))
        .whenLocalFirst(
          loading: () => const ImagePlaceholder(
            height: AudioGuideSection.height,
            borderRadius: AppRadii.mdAll,
          ),
          error: (error, _) => QuietNote(
            errorCopy("Couldn't load the audio guide.", error),
            onRetry: () => ref.invalidate(destinationSegmentsProvider(id)),
          ),
          data: (stops) => stops.isEmpty
              ? null
              // The card names itself, so no heading over it.
              : AudioGuideSection(
                  destinationId: id,
                  segments: stops,
                  cover: cover,
                ),
        );
    if (guide == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: _gap),
      child: guide,
    );
  }
}

/// Add to Trip, floating at the bottom trailing corner: an emerald capsule that
/// folds to its glyph while reading. Takes its own `SafeArea`.
class _PinnedAction extends StatelessWidget {
  const _PinnedAction({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  /// The button, its gutter all round, and the gesture inset under it.
  static double extentOf(BuildContext context) =>
      AppSize.primaryButton +
      AppSpace.gutter * 2 +
      MediaQuery.viewPaddingOf(context).bottom;

  @override
  Widget build(BuildContext context) {
    final compact = _Compact.of(context);
    return Positioned(
      right: 0,
      bottom: 0,
      // Own RepaintBoundary so folding repaints only the action.
      child: RepaintBoundary(
        child: SafeArea(
          top: false,
          minimum: const EdgeInsets.all(AppSpace.gutter),
          child: Pressable(
            enabled: onPressed != null,
            child: Tooltip(
              message: label,
              excludeFromSemantics: true,
              child: FilledButton(
                onPressed: onPressed,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.square(AppSize.primaryButton),
                  padding: const EdgeInsets.symmetric(
                    horizontal: (AppSize.primaryButton - AppSize.glyph) / 2,
                  ),
                ),
                child: Semantics(
                  label: label,
                  excludeSemantics: true,
                  child: AppMotionBuilder(
                    end: compact ? 0 : 1,
                    builder: (context, t, _) {
                      final open = t.clamp(0.0, 1.0);
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(icon, size: AppSize.glyph),
                          if (open > 0)
                            ClipRect(
                              child: Align(
                                alignment: Alignment.centerLeft,
                                widthFactor: open,
                                child: Padding(
                                  padding: const EdgeInsets.only(
                                    left: AppSpace.x2,
                                  ),
                                  child: Opacity(
                                    opacity: open,
                                    child: Text(label, maxLines: 1),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Folds [_PinnedAction] after a deliberate scroll down, opens it on a scroll
/// up or at the top, and keeps it folded at the bottom over the last row.
class _PinnedActionScope extends StatefulWidget {
  const _PinnedActionScope({required this.child});

  final Widget child;

  @override
  State<_PinnedActionScope> createState() => _PinnedActionScopeState();
}

class _PinnedActionScopeState extends State<_PinnedActionScope> {
  bool _compact = false;
  double _travel = 0;

  static const _foldAfter = AppSpace.x12;
  static const _openAfter = AppSpace.x6;

  bool _onScroll(ScrollNotification notification) {
    final metrics = notification.metrics;
    if (metrics.axis != Axis.vertical || notification.depth != 0) return false;
    if (notification is! ScrollUpdateNotification) return false;
    final atTop = metrics.pixels <= metrics.minScrollExtent;
    final atBottom = metrics.pixels >= metrics.maxScrollExtent;
    final delta = notification.scrollDelta ?? 0;
    if ((delta > 0) != (_travel > 0)) _travel = 0;
    _travel += delta;
    final compact = atTop
        ? false
        : atBottom
        ? true
        : _travel > _foldAfter
        ? true
        : _travel < -_openAfter
        ? false
        : _compact;
    if (compact != _compact) setState(() => _compact = compact);
    return false;
  }

  @override
  Widget build(BuildContext context) =>
      NotificationListener<ScrollNotification>(
        onNotification: _onScroll,
        child: _Compact(compact: _compact, child: widget.child),
      );
}

class _Compact extends InheritedWidget {
  const _Compact({required this.compact, required super.child});

  final bool compact;

  static bool of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_Compact>()?.compact ?? false;

  @override
  bool updateShouldNotify(_Compact old) => compact != old.compact;
}
