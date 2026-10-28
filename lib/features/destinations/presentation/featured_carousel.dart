import "dart:ui" show lerpDouble;

import "package:flutter/material.dart";
import "package:go_router/go_router.dart";

import "../../../core/models/destination.dart";
import "../../../core/router/app_router.dart";
import "../../../core/theme/app_dimens.dart";
import "../../../core/theme/app_motion.dart";
import "../../../core/theme/app_typography.dart";
import "../../../core/widgets/content/media_tile.dart";
import "../../../core/widgets/content/page_dots.dart";
import "../../../core/widgets/content/storage_image.dart";
import "../../../core/widgets/motion/motion.dart";
import "../../../core/widgets/motion/page_transitions.dart";
import "../../itineraries/presentation/add_to_itinerary_sheet.dart";
import "save_heart.dart";

/// Full-width swipeable featured-places carousel. Photo trails the card
/// on a parallax; only the centred card shows the primary action.
/// Height is measured from the text scaler, not clipped.
class FeaturedCarousel extends StatefulWidget {
  const FeaturedCarousel({required this.places, super.key});

  final List<Destination> places;

  @override
  State<FeaturedCarousel> createState() => _FeaturedCarouselState();
}

class _FeaturedCarouselState extends State<FeaturedCarousel> {
  final _pages = PageController();
  int _page = 0;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  /// Caption height at the user's text size, each line scaled independently.
  double _height(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    final caption =
        scaler.lineHeightOf(AppTypography.labelMedium) +
        2 * scaler.lineHeightOf(AppTypography.hero) +
        scaler.lineHeightOf(AppTypography.bodyMedium) +
        AppSize.primaryButton +
        AppSpace.x12 * 3;
    final floor = AppSize.featuredCard;
    return (caption > floor ? caption : floor).ceilToDouble();
  }

  @override
  Widget build(BuildContext context) {
    final places = widget.places;
    return Column(
      children: [
        SizedBox(
          height: _height(context),
          child: PageView.builder(
            controller: _pages,
            itemCount: places.length,
            onPageChanged: (page) => setState(() => _page = page),
            itemBuilder: (context, index) => _Page(
              controller: _pages,
              index: index,
              child: _Card(
                place: places[index],
                centred: index == _page,
                pages: _pages,
                index: index,
              ),
            ),
          ),
        ),
        if (places.length > 1) ...[
          const SizedBox(height: AppSpace.x2),
          PageDots(count: places.length, current: _page),
        ],
      ],
    );
  }
}

/// A card's place in the row: it steps back as it leaves the middle. Only
/// the transform rebuilds as the pages move; the card is built once.
class _Page extends StatelessWidget {
  const _Page({
    required this.controller,
    required this.index,
    required this.child,
  });

  final PageController controller;
  final int index;
  final Widget child;

  static const _sideScale = 0.94;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    child: child,
    builder: (context, child) {
      final away = _offsetOf(controller, index).abs().clamp(0.0, 1.0);
      return Transform.scale(
        scale: lerpDouble(1, _sideScale, away),
        child: child,
      );
    },
  );
}

/// Before the first layout a controller has no page; the first card is in
/// the middle.
double _offsetOf(PageController controller, int index) {
  if (!controller.hasClients || !controller.position.haveDimensions) {
    return index.toDouble();
  }
  return index - (controller.page ?? 0);
}

class _Card extends StatelessWidget {
  const _Card({
    required this.place,
    required this.centred,
    required this.pages,
    required this.index,
  });

  final Destination place;
  final bool centred;
  final PageController pages;
  final int index;

  @override
  Widget build(BuildContext context) {
    void open() =>
        context.push(Routes.destination(place.id, from: HeroSource.featured));

    // The whole card opens the place, caption and all. The heart and the
    // one action are inner targets, so a tap on either stays theirs.
    return Pressable(
      child: GestureDetector(
        onTap: open,
        behavior: HitTestBehavior.opaque,
        child: ClipRect(
          child: Stack(
            fit: StackFit.expand,
            children: [
              // The card's own frame flies, the parallax inside it, so the
              // photo leaves from exactly where the card is.
              PhotoHero(
                tag: coverHeroTag(place.id, HeroSource.featured),
                child: ClipRect(
                  child: _Parallax(
                    pages: pages,
                    index: index,
                    child: CoverImage(place.coverImage),
                  ),
                ),
              ),
              Positioned(
                top: AppSpace.x3,
                left: AppSpace.x3,
                right: AppSpace.x3,
                child: Row(
                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: AppSpace.x2,
                        runSpacing: AppSpace.x2,
                        children: [if (place.hasAR) const PhotoPill.scan()],
                      ),
                    ),
                    SaveHeart(place.id, style: SaveHeartStyle.hero),
                  ],
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: MediaScrim(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpace.x3,
                    AppSpace.x12,
                    AppSpace.x3,
                    AppSpace.x3,
                  ),
                  child: _Caption(place: place, centred: centred),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Parallax photo: a fifth wider than its card, translated against the swipe.
/// Built once; only the translation follows the pages.
class _Parallax extends StatelessWidget {
  const _Parallax({
    required this.pages,
    required this.index,
    required this.child,
  });

  final PageController pages;
  final int index;
  final Widget child;

  static const _overscan = 0.2;

  /// Half the overscan, as a share of the photo's own (wider) width.
  static const _travel = _overscan / 2 / (1 + _overscan);

  @override
  Widget build(BuildContext context) => FractionallySizedBox(
    widthFactor: 1 + _overscan,
    child: MediaQuery.disableAnimationsOf(context)
        ? child
        : AnimatedBuilder(
            animation: pages,
            child: child,
            builder: (context, child) => FractionalTranslation(
              translation: Offset(
                _offsetOf(pages, index).clamp(-1.0, 1.0) * _travel,
                0,
              ),
              child: child,
            ),
          ),
  );
}

class _Caption extends StatelessWidget {
  const _Caption({required this.place, required this.centred});

  final Destination place;
  final bool centred;

  @override
  Widget build(BuildContext context) {
    const white = Colors.white;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          place.town,
          style: AppTypography.labelMedium.copyWith(color: white),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          place.name,
          style: AppTypography.hero.copyWith(color: white),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          place.description,
          style: AppTypography.bodyMedium.copyWith(color: white),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: AppSpace.x2),
        Row(
          children: [
            // Only the middle card offers it, so the screen has one primary
            // action; the others keep its room so nothing shifts.
            ExcludeSemantics(
              excluding: !centred,
              child: IgnorePointer(
                ignoring: !centred,
                child: AnimatedOpacity(
                  opacity: centred ? 1 : 0,
                  duration: AppMotion.edge,
                  child: Pressable(
                    child: FilledButton(
                      onPressed: () => showAddToItinerary(
                        context,
                        destinationId: place.id,
                        destinationName: place.name,
                      ),
                      child: const Text("Add to a tour"),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
