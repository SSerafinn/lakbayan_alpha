import "dart:math" show max;

import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:motor/motor.dart";

import "../../../core/router/app_router.dart";
import "../../../core/theme/app_dimens.dart";
import "../../../core/theme/app_icons.dart";
import "../../../core/theme/app_motion.dart";
import "../../../core/theme/app_theme.dart";
import "../../../core/widgets/chrome/system_bars.dart";
import "../../../core/widgets/content/page_dots.dart";
import "../../../core/widgets/content/storage_image.dart";
import "../../../core/widgets/controls/symbol_button.dart";
import "../../../core/widgets/motion/motion.dart";
import "../../../core/widgets/motion/page_transitions.dart";
import "../domain/destination_providers.dart";
import "destination_detail_screen.dart" show sharePlace;

/// A place's photos, full screen on a dark stage in either appearance
/// (D-19). Opened from a photo on its page, which zooms into it; close,
/// back or a pull down shrinks the photo showing back into its tile. The
/// stage is that photo decoded tiny and stretched, a blur with no filter
/// (STANDARDS 10.7); the dots and a strip of the photos sit at its foot.
class PhotoViewer extends ConsumerStatefulWidget {
  const PhotoViewer({required this.id, required this.at, super.key});

  final String id;

  /// The photo it opens on.
  final int at;

  @override
  ConsumerState<PhotoViewer> createState() => _PhotoViewerState();
}

class _PhotoViewerState extends ConsumerState<PhotoViewer>
    with SingleTickerProviderStateMixin {
  late final _pages = PageController(initialPage: widget.at);
  late int _page = widget.at;

  /// How far the photo has been pulled down; it springs home if let go
  /// short of leaving.
  late final _pull = SingleMotionController(
    motion: AppMotion.chrome,
    vsync: this,
    initialValue: 0,
  );

  /// The stage's blur: a photo this many pixels wide, stretched.
  static const _blurWidth = 32;

  @override
  void dispose() {
    _pages.dispose();
    _pull.dispose();
    super.dispose();
  }

  void _release(DragEndDetails details) {
    final speed = details.primaryVelocity ?? 0;
    final far = MediaQuery.sizeOf(context).height / 5;
    if (_pull.value > far || speed > AppMotion.flingSpeed) {
      context.popOrHome();
    } else if (MediaQuery.disableAnimationsOf(context)) {
      _pull.value = 0;
    } else {
      _pull.animateTo(0, withVelocity: speed);
    }
  }

  void _show(int index) => _pages.animateToPage(
    index,
    duration: AppMotion.span,
    curve: SpringCurve(AppMotion.chrome, AppMotion.span),
  );

  @override
  Widget build(BuildContext context) {
    final place = ref.watch(destinationByIdProvider(widget.id)).value;
    final images = place?.images ?? const <String>[];
    final page = _page.clamp(0, images.isEmpty ? 0 : images.length - 1);
    final inset = MediaQuery.viewPaddingOf(context);

    return Theme(
      data: _stageTheme,
      child: Builder(
        builder: (context) => Scaffold(
          body: SystemBars(
            overPhoto: true,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (images.isNotEmpty)
                  FadeSwap(
                    id: page,
                    child: StorageImage(
                      path: images[page],
                      decodeWidth: _blurWidth,
                    ),
                  ),
                ColoredBox(color: Theme.of(context).colorScheme.scrim),
                GestureDetector(
                  onVerticalDragUpdate: (details) =>
                      _pull.value = max(0, _pull.value + details.delta.dy),
                  onVerticalDragEnd: _release,
                  child: AnimatedBuilder(
                    animation: _pull,
                    child: PageView.builder(
                      controller: _pages,
                      itemCount: images.length,
                      onPageChanged: (index) => setState(() => _page = index),
                      itemBuilder: (context, index) {
                        final photo = StorageImage(path: images[index]);
                        return Center(
                          child: AspectRatio(
                            aspectRatio: 4 / 3,
                            // Only the photo showing flies, back to its tile.
                            child: index == page
                                ? PhotoHero(
                                    tag: photoHeroTag(widget.id, index),
                                    child: photo,
                                  )
                                : photo,
                          ),
                        );
                      },
                    ),
                    builder: (context, photos) {
                      final pull = _pull.value;
                      final shrink =
                          1 - pull / MediaQuery.sizeOf(context).height / 2;
                      return Transform.translate(
                        offset: Offset(0, pull),
                        child: Transform.scale(scale: shrink, child: photos),
                      );
                    },
                  ),
                ),
                Positioned(
                  top: inset.top + AppSpace.x2,
                  left: AppSpace.x2,
                  right: AppSpace.x2,
                  child: Row(
                    children: [
                      SymbolButton(
                        icon: AppIcons.close,
                        tooltip: "Close",
                        onTap: context.popOrHome,
                      ),
                      const Spacer(),
                      if (place != null)
                        SymbolButton(
                          icon: AppIcons.share,
                          tooltip: "Share",
                          onTap: () => sharePlace(context, ref, place),
                        ),
                    ],
                  ),
                ),
                if (images.length > 1)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: inset.bottom + AppSpace.x6,
                    child: Column(
                      children: [
                        PageDots(count: images.length, current: page),
                        const SizedBox(height: AppSpace.x3),
                        _Strip(images: images, current: page, onTap: _show),
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

/// The viewer's stage, dark whatever the phone's appearance.
final _stageTheme = buildAppDarkTheme();

/// Every photo small, the one showing wider and ringed; a tap shows it.
class _Strip extends StatelessWidget {
  const _Strip({
    required this.images,
    required this.current,
    required this.onTap,
  });

  final List<String> images;
  final int current;
  final ValueChanged<int> onTap;

  static const _side = AppSize.rowMediaDense;

  /// Decoded once at a fixed width, so the one growing never re-decodes
  /// (STANDARDS 10.14).
  static const _decode = 160;

  @override
  Widget build(BuildContext context) {
    final ring = Theme.of(context).colorScheme.onSurface;
    return SizedBox(
      height: _side,
      child: Center(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.gutter),
          child: Row(
            children: [
              for (final (index, path) in images.indexed) ...[
                if (index > 0) const SizedBox(width: AppSpace.x1),
                Semantics(
                  button: true,
                  selected: index == current,
                  label: "Photo ${index + 1} of ${images.length}",
                  child: GestureDetector(
                    onTap: () => onTap(index),
                    child: AppMotionBuilder(
                      end: index == current ? 1 : 0,
                      child: ClipRRect(
                        borderRadius: AppRadii.xsAll,
                        child: StorageImage(path: path, decodeWidth: _decode),
                      ),
                      builder: (context, t, photo) => Container(
                        width: _side * (1 + t.clamp(0.0, 1.0) / 2),
                        padding: const EdgeInsets.all(AppStroke.bold),
                        decoration: ShapeDecoration(
                          shape: RoundedRectangleBorder(
                            borderRadius: AppRadii.smAll,
                            side: BorderSide(
                              color: ring.withValues(alpha: t.clamp(0.0, 1.0)),
                              width: AppStroke.bold,
                            ),
                          ),
                        ),
                        child: photo,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
