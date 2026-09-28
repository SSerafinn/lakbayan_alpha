import "dart:ui" show lerpDouble;

import "package:flutter/material.dart";
import "package:motor/motor.dart";

import "../theme/app_dimens.dart";
import "../theme/app_motion.dart";
import "app_destination.dart";
import "app_motion_builder.dart";
import "floating_tab_item.dart";

export "floating_tab_item.dart";

/// The bottom tab bar: a floating white capsule with a hairline, inset
/// [AppSpace.gutter], content flowing under it. Moves between the top level
/// sections and nothing else. A solid green capsule wraps the active item.
///
/// [collapsed] drops the labels to a capsule of glyphs one touch target tall
/// after a deliberate scroll down; [hidden] slides it off the bottom edge while
/// a surface needs that space. Real width and height are tweened, so the bar
/// is a capsule at every size along the way; reduced motion cross-fades.
class FloatingTabBar extends StatelessWidget {
  const FloatingTabBar({
    required this.destinations,
    required this.selectedIndex,
    required this.onSelected,
    this.collapsed = false,
    this.hidden = false,
    this.onExpand,
    super.key,
  });

  final List<AppDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  final bool collapsed;
  final bool hidden;
  final VoidCallback? onExpand;

  @override
  Widget build(BuildContext context) {
    void tap(int index) {
      if (collapsed) onExpand?.call();
      onSelected(index);
    }

    // heightFactor: hug the bar; a bare Align would fill bounded height.
    final bar = Align(
      alignment: Alignment.bottomCenter,
      heightFactor: 1,
      child: AppMotionBuilder(
        end: collapsed ? 0 : 1,
        builder: (context, expansion, _) => _Bar(
          destinations: destinations,
          selectedIndex: selectedIndex,
          expansion: expansion,
          onTap: tap,
        ),
      ),
    );

    // Hidden is a slide off the edge, so it is clear where the bar went and
    // where it comes back from; reduced motion fades instead. Once settled
    // off screen the bar is not in the tree at all (STANDARDS 10.1).
    return IgnorePointer(
      ignoring: hidden,
      child: MediaQuery.disableAnimationsOf(context)
          ? AnimatedSwitcher(
              duration: AppMotion.edge,
              child: hidden ? const SizedBox.shrink() : bar,
            )
          : SingleMotionBuilder(
              motion: AppMotion.chrome,
              value: hidden ? 2 : 0,
              child: bar,
              builder: (context, dy, child) => dy >= 2
                  ? const SizedBox.shrink()
                  : FractionalTranslation(
                      translation: Offset(0, dy),
                      child: child,
                    ),
            ),
    );
  }
}

/// The bar at one point between collapsed (0) and rest (1). The indicator's
/// index is a spring too, so a tab switch mid-morph never jumps.
class _Bar extends StatelessWidget {
  const _Bar({
    required this.destinations,
    required this.selectedIndex,
    required this.expansion,
    required this.onTap,
  });

  final List<AppDestination> destinations;
  final int selectedIndex;
  final double expansion;
  final ValueChanged<int> onTap;

  static const _inset = 5.0;
  static const _gap = 4.0;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final count = destinations.length;
    final t = expansion;
    final height = lerpDouble(
      AppSize.bottomNavCollapsed,
      AppSize.bottomNav,
      t,
    )!;
    final indicatorHeight = height - 2 * _inset;

    return LayoutBuilder(
      builder: (context, constraints) {
        final collapsedWidth =
            count * AppSize.minTouchTarget + 2 * _inset + (count - 1) * _gap;
        final width = lerpDouble(collapsedWidth, constraints.maxWidth, t)!;
        final itemWidth = (width - 2 * _inset - (count - 1) * _gap) / count;
        // A circle around the glyph when collapsed, a capsule when at rest.
        final indicatorWidth = lerpDouble(indicatorHeight, itemWidth, t)!;

        return Material(
          color: scheme.surface,
          shape: StadiumBorder(side: BorderSide(color: scheme.outlineVariant)),
          clipBehavior: Clip.antiAlias,
          child: SizedBox(
            width: width,
            height: height,
            child: SingleMotionBuilder(
              motion: AppMotion.chrome,
              value: selectedIndex.toDouble(),
              builder: (context, index, _) => Stack(
                children: [
                  Positioned(
                    left:
                        _inset +
                        index * (itemWidth + _gap) +
                        (itemWidth - indicatorWidth) / 2,
                    top: _inset,
                    width: indicatorWidth,
                    height: indicatorHeight,
                    child: DecoratedBox(
                      decoration: ShapeDecoration(
                        color: scheme.primary,
                        shape: capsule,
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: Padding(
                      padding: const EdgeInsets.all(_inset),
                      child: Row(
                        children: [
                          for (var i = 0; i < count; i++) ...[
                            if (i > 0) const SizedBox(width: _gap),
                            Expanded(
                              child: FloatingTabItem(
                                destination: destinations[i],
                                selectionAmount: (1 - (index - i).abs()).clamp(
                                  0.0,
                                  1.0,
                                ),
                                expansion: t,
                                onTap: () => onTap(i),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
