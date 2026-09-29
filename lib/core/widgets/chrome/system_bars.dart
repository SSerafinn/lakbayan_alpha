import "package:flutter/material.dart";
import "package:flutter/services.dart";

/// The status and navigation bars' icon style for the region under [child].
///
/// The bars are transparent; only their icons change: dark on the white
/// ground, light in dark mode and over a photo ([overPhoto]). Flutter reads
/// the region under each bar from the layer tree every frame, so wrapping a
/// photo header is enough: no scroll listener, no rebuild.
class SystemBars extends StatelessWidget {
  const SystemBars({required this.child, this.overPhoto = false, super.key});

  final Widget child;
  final bool overPhoto;

  @override
  Widget build(BuildContext context) {
    final lightIcons =
        overPhoto || Theme.of(context).brightness == Brightness.dark;
    final base = lightIcons
        ? SystemUiOverlayStyle.light
        : SystemUiOverlayStyle.dark;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: base.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarContrastEnforced: false,
      ),
      child: child,
    );
  }
}

/// The opaque ground behind the status bar, so scrolled content never runs
/// under the clock, the camera cutout or the battery. Goes in a screen's
/// `Stack` after the content; a fill, never a blur (STANDARDS 6.6, 10.7).
///
/// [StatusBarGround.new] is always there (a tab, a list).
/// [StatusBarGround.below] leaves the status bar to a resting header photo
/// or map and closes in under it as the page's content reaches it.
class StatusBarGround extends StatelessWidget {
  const StatusBarGround({super.key}) : scroll = null, contentTop = 0;

  const StatusBarGround.below({
    required ScrollController this.scroll,
    required this.contentTop,
    super.key,
  });

  final ScrollController? scroll;

  /// Where the page's content starts in [scroll]'s coordinates.
  final double contentTop;

  @override
  Widget build(BuildContext context) {
    final strip = SystemBars(
      child: ColoredBox(color: Theme.of(context).colorScheme.surface),
    );
    final scroll = this.scroll;
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      height: MediaQuery.viewPaddingOf(context).top,
      child: IgnorePointer(
        child: scroll == null
            ? strip
            : CustomSingleChildLayout(
                delegate: _Closing(scroll: scroll, contentTop: contentTop),
                child: strip,
              ),
      ),
    );
  }
}

/// Lays the strip from the page's edge down to the status bar's foot at
/// layout time: a scroll frame is a layout of one box, never a build. Only
/// the visible part carries the icon style.
class _Closing extends SingleChildLayoutDelegate {
  _Closing({required this.scroll, required this.contentTop})
    : super(relayout: scroll);

  final ScrollController scroll;
  final double contentTop;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    final height = constraints.maxHeight;
    final offset = scroll.hasClients ? scroll.offset : 0.0;
    final top = (contentTop - offset).clamp(0.0, height);
    return BoxConstraints.tightFor(
      width: constraints.maxWidth,
      height: height - top,
    );
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) =>
      Offset(0, size.height - childSize.height);

  @override
  bool shouldRelayout(_Closing old) =>
      old.scroll != scroll || old.contentTop != contentTop;
}
