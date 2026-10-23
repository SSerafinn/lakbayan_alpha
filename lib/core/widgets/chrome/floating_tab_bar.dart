import "dart:ui" show lerpDouble;

import "package:flutter/material.dart";
import "package:motor/motor.dart";

import "../../theme/app_dimens.dart";
import "../../theme/app_icons.dart";
import "../../theme/app_motion.dart";
import "../motion/motion.dart";

/// The bottom navigation bar: the four sections and search in one white
/// capsule, glyphs only, an emerald pill sliding to the chosen section, whose
/// glyph fills in. The names are each cell's tooltip and semantics label.
/// Shrinks on a deliberate scroll down, every cell still one tap; hides
/// fully when a surface needs the space.
class FloatingTabBar extends StatelessWidget {
  const FloatingTabBar({
    required this.destinations,
    required this.selectedIndex,
    required this.onSelected,
    required this.onSearch,
    this.searchKey,
    this.collapsed = false,
    this.hidden = false,
    this.searchOpen = false,
    this.onExpand,
    super.key,
  });

  final List<AppDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final VoidCallback onSearch;

  /// On the search cell, so search can grow out of exactly where it is.
  final GlobalKey? searchKey;

  /// Shrunk, after a deliberate scroll down.
  final bool collapsed;
  final bool hidden;
  final bool searchOpen;

  /// The chosen section tapped while shrunk: grow the bar back.
  final VoidCallback? onExpand;

  /// How small the bar gets: exactly one touch target tall, so every cell
  /// still meets the minimum.
  static const _shrunk = AppSize.bottomNavCollapsed / AppSize.bottomNav;

  /// What the bar covers at a tab's foot; a tab pads its scroll end by this.
  static double clearance(BuildContext context) =>
      MediaQuery.viewPaddingOf(context).bottom +
      AppSize.bottomNav +
      AppSpace.x3;

  @override
  Widget build(BuildContext context) {
    final bar = RepaintBoundary(
      child: _Bar(
        destinations: destinations,
        selectedIndex: selectedIndex,
        collapsed: collapsed,
        searchOpen: searchOpen,
        searchKey: searchKey,
        onSelected: onSelected,
        onSearch: onSearch,
        onExpand: onExpand,
      ),
    );

    // Shrinks as one transform over the bar's kept picture, never a layout.
    final sized = AppMotionBuilder(
      end: collapsed ? 0 : 1,
      child: bar,
      builder: (context, t, bar) => Transform.scale(
        scale: lerpDouble(_shrunk, 1, t),
        alignment: Alignment.bottomCenter,
        child: bar,
      ),
    );

    // Hidden, it slides off (fades under reduced motion) and goes offstage,
    // never removed, so it returns with its state (STANDARDS 10.13). One bar
    // at a time: it holds the search cell's GlobalKey.
    return IgnorePointer(
      ignoring: hidden || searchOpen,
      child: MediaQuery.disableAnimationsOf(context)
          ? AnimatedOpacity(
              duration: AppMotion.edge,
              opacity: hidden ? 0 : 1,
              child: sized,
            )
          : SingleMotionBuilder(
              motion: AppMotion.chrome,
              value: hidden ? 2 : 0,
              child: sized,
              builder: (context, dy, child) => Offstage(
                offstage: dy >= 2,
                child: FractionalTranslation(
                  translation: Offset(0, dy),
                  child: child,
                ),
              ),
            ),
    );
  }
}

/// The bar's parts. Two springs (search parting it, the pill sliding) drive
/// layout and paint; nothing rebuilds per frame.
class _Bar extends StatefulWidget {
  const _Bar({
    required this.destinations,
    required this.selectedIndex,
    required this.collapsed,
    required this.searchOpen,
    required this.searchKey,
    required this.onSelected,
    required this.onSearch,
    required this.onExpand,
  });

  final List<AppDestination> destinations;
  final int selectedIndex;
  final bool collapsed;
  final bool searchOpen;
  final GlobalKey? searchKey;
  final ValueChanged<int> onSelected;
  final VoidCallback onSearch;
  final VoidCallback? onExpand;

  @override
  State<_Bar> createState() => _BarState();
}

class _BarState extends State<_Bar> with TickerProviderStateMixin {
  late final _parting = SingleMotionController(
    motion: AppMotion.chrome,
    vsync: this,
    initialValue: widget.searchOpen ? 1 : 0,
  );

  /// The pill's way from [_from] to the chosen section, 0 to 1.
  late final _travel = SingleMotionController(
    motion: AppMotion.chrome,
    vsync: this,
    initialValue: 1,
  );
  late int _from = widget.selectedIndex;
  late final _fade = AnimationController(
    vsync: this,
    duration: AppMotion.edge,
    value: 1,
  );

  /// What moves the glyphs' ink and the cells.
  late final Listenable _moves = Listenable.merge([_parting, _travel]);

  @override
  void didUpdateWidget(_Bar old) {
    super.didUpdateWidget(old);
    final reduced = MediaQuery.disableAnimationsOf(context);
    var moved = false;
    if (widget.searchOpen != old.searchOpen) {
      moved = true;
      final to = widget.searchOpen ? 1.0 : 0.0;
      if (reduced) {
        _parting.value = to;
      } else {
        _parting.animateTo(to);
      }
    }
    if (widget.selectedIndex != old.selectedIndex) {
      moved = true;
      _from = old.selectedIndex;
      _travel.value = reduced ? 1 : 0;
      if (!reduced) _travel.animateTo(1);
    }
    if (reduced && moved) _fade.forward(from: 0);
  }

  @override
  void dispose() {
    _parting.dispose();
    _travel.dispose();
    _fade.dispose();
    super.dispose();
  }

  /// The bar's rects at this frame.
  TabBarLayout _layoutAt(double width) => TabBarLayout(
    width: width,
    count: widget.destinations.length,
    parting: _parting.value.clamp(0.0, 1.0),
    from: _from,
    to: widget.selectedIndex,
    travel: _travel.value,
  );

  /// How far a section is chosen right now, 0 to 1: the pill's share of it,
  /// gone as search opens.
  double _chosen(int position) {
    final shown = 1 - _parting.value.clamp(0.0, 1.0);
    final travel = _travel.value.clamp(0.0, 1.0);
    final to = widget.selectedIndex;
    if (position == to) return (_from == to ? 1 : travel) * shown;
    if (position == _from) return (1 - travel) * shown;
    return 0;
  }

  /// Every cell answers while shrunk; the chosen one grows the bar back.
  void _tapped(int index) {
    if (index != widget.selectedIndex) {
      widget.onSelected(index);
    } else if (widget.collapsed) {
      widget.onExpand?.call();
    }
  }

  /// A glyph's colour at paint time: on the pill's colour as it is chosen,
  /// grey elsewhere, fading as search opens.
  Color _inkOf(int position, Color rest, Color onPill) {
    final colour = Color.lerp(rest, onPill, _chosen(position))!;
    final shown = 1 - _parting.value.clamp(0.0, 1.0);
    return colour.withValues(alpha: colour.a * shown);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final destinations = widget.destinations;
    final rest = scheme.onSurfaceVariant;

    return FadeTransition(
      opacity: _fade,
      child: CustomMultiChildLayout(
        delegate: _BarLayout(layoutAt: _layoutAt, moves: _moves),
        children: [
          LayoutId(
            id: _BarPart.ground,
            child: CustomPaint(
              painter: _GroundPainter(
                layoutAt: _layoutAt,
                moves: _moves,
                parting: _parting,
                fill: scheme.surfaceContainerLowest,
                hairline: scheme.outlineVariant,
                indicator: scheme.primary,
              ),
            ),
          ),
          for (var i = 0; i < destinations.length; i++)
            LayoutId(
              id: i,
              child: _Cell(
                label: destinations[i].label,
                selected: i == widget.selectedIndex,
                onTap: () => _tapped(i),
                glyph: _SectionGlyph(
                  icon: destinations[i].icon,
                  selectedIcon: destinations[i].selectedIcon,
                  ink: () => _inkOf(i, rest, scheme.onPrimary),
                  chosen: () => _chosen(i),
                  moves: _moves,
                ),
              ),
            ),
          LayoutId(
            id: _BarPart.search,
            // While open, the search surface draws the field from here.
            child: _AtRest(
              parting: _parting,
              child: KeyedSubtree(
                key: widget.searchKey,
                child: _Cell(
                  label: "Search",
                  onTap: widget.onSearch,
                  glyph: Icon(
                    AppIcons.search,
                    size: AppSize.tabGlyph,
                    color: rest,
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

enum _BarPart { ground, search }

/// Places the cells from [TabBarLayout]; a frame of search opening or of a
/// section being chosen is a layout pass, never a build.
class _BarLayout extends MultiChildLayoutDelegate {
  _BarLayout({required this.layoutAt, required this.moves})
    : super(relayout: moves);

  final TabBarLayout Function(double width) layoutAt;
  final Listenable moves;

  @override
  Size getSize(BoxConstraints constraints) =>
      constraints.constrain(Size(constraints.maxWidth, AppSize.bottomNav));

  @override
  void performLayout(Size size) {
    final layout = layoutAt(size.width);
    layoutChild(_BarPart.ground, BoxConstraints.tight(size));
    positionChild(_BarPart.ground, Offset.zero);
    for (var i = 0; i < layout.cells.length - 1; i++) {
      final cell = layout.cells[i];
      layoutChild(i, BoxConstraints.tight(cell.size));
      positionChild(i, cell.topLeft);
    }
    layoutChild(_BarPart.search, BoxConstraints.tight(layout.search.size));
    positionChild(_BarPart.search, layout.search.topLeft);
  }

  @override
  bool shouldRelayout(_BarLayout old) => true;
}

/// The capsule and the pill, painted from the springs; fading by colour,
/// not `Opacity`, so no `saveLayer`.
class _GroundPainter extends CustomPainter {
  _GroundPainter({
    required this.layoutAt,
    required this.moves,
    required this.parting,
    required this.fill,
    required this.hairline,
    required this.indicator,
  }) : super(repaint: moves);

  final TabBarLayout Function(double width) layoutAt;
  final Listenable moves;
  final Animation<double> parting;
  final Color fill;
  final Color hairline;
  final Color indicator;

  @override
  void paint(Canvas canvas, Size size) {
    final shown = 1 - parting.value.clamp(0.0, 1.0);
    final layout = layoutAt(size.width);
    canvas.drawPath(
      capsule.getOuterPath(layout.capsule),
      Paint()..color = fill.withValues(alpha: fill.a * shown),
    );
    StadiumBorder(
      side: BorderSide(color: hairline.withValues(alpha: hairline.a * shown)),
    ).paint(canvas, layout.capsule);
    canvas.drawPath(
      capsule.getOuterPath(layout.indicator),
      Paint()..color = indicator.withValues(alpha: indicator.a * shown),
    );
  }

  @override
  bool shouldRepaint(_GroundPainter old) => true;
}

/// Shows [child] only while [parting] rests at 0; rebuilds on the flip,
/// not every frame.
class _AtRest extends StatefulWidget {
  const _AtRest({required this.parting, required this.child});

  final Animation<double> parting;
  final Widget child;

  @override
  State<_AtRest> createState() => _AtRestState();
}

class _AtRestState extends State<_AtRest> {
  late bool _rested = widget.parting.value <= 0;

  @override
  void initState() {
    super.initState();
    widget.parting.addListener(_check);
  }

  @override
  void didUpdateWidget(_AtRest old) {
    super.didUpdateWidget(old);
    if (old.parting != widget.parting) {
      old.parting.removeListener(_check);
      widget.parting.addListener(_check);
      _check();
    }
  }

  @override
  void dispose() {
    widget.parting.removeListener(_check);
    super.dispose();
  }

  void _check() {
    final rested = widget.parting.value <= 0;
    if (rested != _rested) setState(() => _rested = rested);
  }

  @override
  Widget build(BuildContext context) =>
      Visibility.maintain(visible: _rested, child: widget.child);
}

/// Where the bar's parts sit: one full-width capsule of equal cells,
/// `[ a  b  c  d  search ]`, and the pill, which travels [from] the last
/// section [to] the chosen one on [travel] (0 to 1). [parting] (0 to 1)
/// slides the capsule out past the leading edge as search opens. The shrink
/// is a transform, so it never changes these rects.
class TabBarLayout {
  factory TabBarLayout({
    required double width,
    required int count,
    required double parting,
    required int from,
    required int to,
    required double travel,
  }) {
    const height = AppSize.bottomNav;
    final push = -width * parting;
    final cells = count + 1;
    final room = width - 2 * inset - (cells - 1) * itemGap;
    final cellWidth = room / cells;
    final rects = [
      for (var i = 0; i < cells; i++)
        Rect.fromLTWH(
          push + inset + i * (cellWidth + itemGap),
          0,
          cellWidth,
          height,
        ),
    ];
    final between = Rect.lerp(rects[from], rects[to], travel)!;
    return TabBarLayout._(
      capsule: Rect.fromLTWH(push, 0, width, height),
      cells: rects,
      indicator: Rect.fromLTRB(
        between.left,
        between.top + inset,
        between.right,
        between.bottom - inset,
      ),
    );
  }

  const TabBarLayout._({
    required this.capsule,
    required this.cells,
    required this.indicator,
  });

  /// The inset between the capsule and the pill inside it.
  static const inset = AppSpace.near;

  /// Between two cells.
  static const itemGap = AppSpace.x1;

  final Rect capsule;

  /// The sections' cells, then search's; each at least a touch target.
  final List<Rect> cells;

  /// The pill, drawn in by [inset] top and bottom. It never reaches search.
  final Rect indicator;

  Rect get search => cells.last;
}

/// One cell, a section or search: its glyph alone. Its name is the
/// semantics label and the long-press tooltip. A section's selection shows
/// two ways: the pill, and the glyph filling in.
class _Cell extends StatelessWidget {
  const _Cell({
    required this.label,
    required this.onTap,
    required this.glyph,
    this.selected = false,
  });

  final String label;
  final VoidCallback onTap;
  final Widget glyph;
  final bool selected;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: label,
    excludeFromSemantics: true,
    child: Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        customBorder: capsule,
        onTap: onTap,
        child: Center(child: glyph),
      ),
    ),
  );
}

/// A section's glyph from `AppIcons`: the outline at rest, the filled one
/// while chosen, the two crossing by their own colour's alpha as the pill
/// arrives, as `SymbolSwap` does. The ink is read at paint time, so a frame
/// of the pill sliding repaints the glyph and never rebuilds it (STANDARDS
/// 10.10), and no layer is opened (10.4).
class _SectionGlyph extends StatefulWidget {
  const _SectionGlyph({
    required this.icon,
    required this.selectedIcon,
    required this.ink,
    required this.chosen,
    required this.moves,
  });

  final IconData icon;
  final IconData selectedIcon;
  final ValueGetter<Color> ink;
  final ValueGetter<double> chosen;
  final Listenable moves;

  @override
  State<_SectionGlyph> createState() => _SectionGlyphState();
}

class _SectionGlyphState extends State<_SectionGlyph> {
  final _outline = TextPainter();
  final _filled = TextPainter();

  @override
  void dispose() {
    _outline.dispose();
    _filled.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: AppSize.tabGlyph,
    child: CustomPaint(
      painter: _GlyphPainter(
        outline: (painter: _outline, icon: widget.icon),
        filled: (painter: _filled, icon: widget.selectedIcon),
        ink: widget.ink,
        chosen: widget.chosen,
        textDirection: Directionality.of(context),
        moves: widget.moves,
      ),
    ),
  );
}

typedef _Glyph = ({TextPainter painter, IconData icon});

class _GlyphPainter extends CustomPainter {
  _GlyphPainter({
    required this.outline,
    required this.filled,
    required this.ink,
    required this.chosen,
    required this.textDirection,
    required Listenable moves,
  }) : super(repaint: moves);

  final _Glyph outline;
  final _Glyph filled;
  final ValueGetter<Color> ink;
  final ValueGetter<double> chosen;
  final TextDirection textDirection;

  @override
  void paint(Canvas canvas, Size size) {
    final t = chosen().clamp(0.0, 1.0);
    final color = ink();
    if (t < 1) {
      _draw(canvas, size, outline, color.withValues(alpha: color.a * (1 - t)));
    }
    if (t > 0) {
      _draw(canvas, size, filled, color.withValues(alpha: color.a * t));
    }
  }

  /// One glyph, centred. Laid out again only when its colour has changed,
  /// so a settled bar paints what it laid out last.
  void _draw(Canvas canvas, Size size, _Glyph glyph, Color color) {
    final (:painter, :icon) = glyph;
    final style = (painter.text as TextSpan?)?.style;
    if (style?.color != color || style?.fontFamily != icon.fontFamily) {
      painter
        ..textDirection = textDirection
        // The glyph's own style, as `Icon` builds it: a font character, not
        // a type step.
        ..text = TextSpan(
          text: String.fromCharCode(icon.codePoint),
          style: TextStyle(
            inherit: false,
            color: color,
            fontSize: size.width,
            fontFamily: icon.fontFamily,
            package: icon.fontPackage,
            height: 1,
          ),
        )
        ..layout();
    }
    final at = Offset(
      (size.width - painter.width) / 2,
      (size.height - painter.height) / 2,
    );
    if (icon.matchTextDirection && textDirection == TextDirection.rtl) {
      canvas
        ..save()
        ..translate(size.width, 0)
        ..scale(-1, 1);
      painter.paint(canvas, at);
      canvas.restore();
    } else {
      painter.paint(canvas, at);
    }
  }

  @override
  bool shouldRepaint(_GlyphPainter old) =>
      old.outline.icon != outline.icon ||
      old.filled.icon != filled.icon ||
      old.textDirection != textDirection;
}

/// One top-level section. Declared once and passed to [FloatingTabBar]: the
/// bar shows [icon], [selectedIcon] while chosen, and [label] as the cell's
/// tooltip and semantics label.
class AppDestination {
  const AppDestination({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
}
