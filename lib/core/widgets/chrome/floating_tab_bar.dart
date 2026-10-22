import "dart:math" show pi, sin;
import "dart:ui" show lerpDouble;

import "package:flutter/material.dart";
import "package:motor/motor.dart";

import "../../theme/app_dimens.dart";
import "../../theme/app_motion.dart";
import "../../theme/app_typography.dart";
import "../motion/motion.dart";

/// The bottom navigation bar: the four sections and search in one white
/// capsule, an emerald pill sliding to the chosen section, whose name grows
/// out of it (D-19). Shrinks on a deliberate scroll down, every cell still
/// one tap; hides fully when a surface needs the space.
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

/// The bar's parts. Two springs (search parting it, the indicator sliding)
/// drive layout and paint; nothing rebuilds per frame.
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

  /// What moves the glyphs' ink, the names and the cells.
  late final Listenable _moves = Listenable.merge([_parting, _travel]);

  /// Each section's name, laid out once per text size and theme.
  List<TextPainter> _names = const [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _layoutNames();
  }

  void _layoutNames() {
    for (final name in _names) {
      name.dispose();
    }
    final style = AppTypography.labelMedium.copyWith(
      color: Theme.of(context).colorScheme.onPrimary,
    );
    _names = [
      for (final destination in widget.destinations)
        TextPainter(
          text: TextSpan(text: destination.label, style: style),
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
          maxLines: 1,
        )..layout(),
    ];
  }

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
    for (final name in _names) {
      name.dispose();
    }
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
    needs: [
      for (final name in _names)
        AppSize.tabGlyph + AppSpace.near + name.width + 2 * AppSpace.x3,
    ],
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
                glyph: TabGlyph(
                  symbol: destinations[i].symbol,
                  selected: i == widget.selectedIndex,
                  size: AppSize.tabGlyph,
                  ink: () => _inkOf(i, rest, scheme.onPrimary),
                  repaint: _moves,
                  cutout: scheme.primary,
                ),
                name: _names[i],
                chosen: () => _chosen(i),
                moves: _moves,
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
                  glyph: TabGlyph(
                    symbol: TabSymbol.search,
                    selected: false,
                    size: AppSize.tabGlyph,
                    ink: () => rest,
                    cutout: scheme.primary,
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

/// Where the bar's parts sit: one full-width capsule of cells,
/// `[ a  b  c  d  search ]`, and the pill. The chosen section is as wide as
/// its glyph and name need ([needs]); the pill travels [from] the last
/// section [to] the chosen one on [travel] (0 to 1), and only those two
/// cells change width on the way. [parting] (0 to 1) slides the capsule out
/// past the leading edge as search opens. The shrink is a transform, so it
/// never changes these rects.
class TabBarLayout {
  factory TabBarLayout({
    required double width,
    required int count,
    required double parting,
    required int from,
    required int to,
    required double travel,
    required List<double> needs,
  }) {
    const height = AppSize.bottomNav;
    final push = -width * parting;
    final cells = count + 1;
    final room = width - 2 * inset - (cells - 1) * itemGap;
    final even = room / cells;
    // The extra a section takes, the others giving it back evenly, so the
    // chosen one at rest is exactly what it needs; never so much that the
    // others drop under a touch target.
    double extra(int position, double share) {
      final need = needs[position].clamp(even, room * _widest);
      return (need - even) * cells / (cells - 1) * share;
    }

    final grow = travel.clamp(0.0, 1.0);
    final extras = [
      for (var i = 0; i < count; i++)
        i == to
            ? extra(i, from == to ? 1 : grow)
            : i == from
            ? extra(i, 1 - grow)
            : 0.0,
    ];
    var taken = 0.0;
    for (final value in extras) {
      taken += value;
    }
    final base = (room - taken) / cells;

    final rects = <Rect>[];
    var x = push + inset;
    for (var i = 0; i < cells; i++) {
      final cellWidth = base + (i < count ? extras[i] : 0);
      rects.add(Rect.fromLTWH(x, 0, cellWidth, height));
      x += cellWidth + itemGap;
    }
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

  /// The most of the bar one chosen section may take.
  static const _widest = 0.4;

  final Rect capsule;

  /// The sections' cells, then search's; each at least a touch target.
  final List<Rect> cells;

  /// The pill, drawn in by [inset] top and bottom. It never reaches search.
  final Rect indicator;

  Rect get search => cells.last;
}

/// One cell, a section or search: its glyph, and for a section its [name]
/// growing out beside it as it is chosen. The name is also the semantics
/// label and the tooltip. A section's selection shows three ways: the pill,
/// the glyph filling in and the name.
class _Cell extends StatelessWidget {
  const _Cell({
    required this.label,
    required this.onTap,
    required this.glyph,
    this.selected = false,
    this.name,
    this.chosen,
    this.moves,
  });

  final String label;
  final VoidCallback onTap;
  final Widget glyph;
  final bool selected;
  final TextPainter? name;
  final ValueGetter<double>? chosen;
  final Listenable? moves;

  @override
  Widget build(BuildContext context) {
    final name = this.name;
    final chosen = this.chosen;
    return Tooltip(
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
          child: name == null || chosen == null
              ? Center(child: glyph)
              : ClipRect(
                  child: CustomMultiChildLayout(
                    delegate: _CellLayout(chosen: chosen, moves: moves),
                    children: [
                      LayoutId(id: _CellPart.glyph, child: glyph),
                      LayoutId(
                        id: _CellPart.name,
                        child: CustomPaint(
                          size: name.size,
                          painter: _NamePainter(
                            name: name,
                            chosen: chosen,
                            moves: moves,
                          ),
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

enum _CellPart { glyph, name }

/// The glyph centred alone, sliding aside as the name comes in beside it.
class _CellLayout extends MultiChildLayoutDelegate {
  _CellLayout({required this.chosen, required Listenable? moves})
    : super(relayout: moves);

  final ValueGetter<double> chosen;

  @override
  void performLayout(Size size) {
    final loose = BoxConstraints.loose(size);
    final glyph = layoutChild(_CellPart.glyph, loose);
    final name = layoutChild(_CellPart.name, const BoxConstraints());
    final group = glyph.width + chosen() * (AppSpace.near + name.width);
    final left = (size.width - group) / 2;
    positionChild(
      _CellPart.glyph,
      Offset(left, (size.height - glyph.height) / 2),
    );
    positionChild(
      _CellPart.name,
      Offset(
        left + glyph.width + AppSpace.near,
        (size.height - name.height) / 2,
      ),
    );
  }

  @override
  bool shouldRelayout(_CellLayout old) => true;
}

/// A section's name, faded in by how chosen it is. Only while it fades is
/// it painted through a layer, and the layer is one short word.
class _NamePainter extends CustomPainter {
  _NamePainter({required this.name, required this.chosen, Listenable? moves})
    : super(repaint: moves);

  final TextPainter name;
  final ValueGetter<double> chosen;

  @override
  void paint(Canvas canvas, Size size) {
    final alpha = chosen().clamp(0.0, 1.0);
    if (alpha == 0) return;
    if (alpha == 1) {
      name.paint(canvas, Offset.zero);
      return;
    }
    canvas.saveLayer(
      Offset.zero & size,
      Paint()..color = Color.fromRGBO(0, 0, 0, alpha),
    );
    name.paint(canvas, Offset.zero);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_NamePainter old) => old.name != name;
}

/// One top-level section. Declared once and passed to [FloatingTabBar]; the
/// bar shows the [symbol], and the chosen section's [label] beside it.
class AppDestination {
  const AppDestination({required this.symbol, required this.label});

  final TabSymbol symbol;
  final String label;
}

/// The four sections and search, all drawn in one box and stroke: a font
/// glyph beside drawn ones never lines up.
enum TabSymbol { explore, map, trips, profile, search }

/// A tab's drawn glyph: outline at rest, filled when selected, with a short
/// animation gesture per symbol (compass swings, map unfolds, etc.).
/// Parts that read through the fill are painted in [cutout] to avoid `saveLayer`.
class TabGlyph extends StatelessWidget {
  const TabGlyph({
    required this.symbol,
    required this.selected,
    required this.ink,
    required this.cutout,
    required this.size,
    this.repaint,
    super.key,
  });

  final TabSymbol symbol;
  final bool selected;

  /// The glyph's colour, read at paint time, so a colour that moves with an
  /// animation (the tab bar's part and indicator) repaints the glyph
  /// without rebuilding it. [repaint] is what it moves with.
  final ValueGetter<Color> ink;
  final Listenable? repaint;
  final Color cutout;
  final double size;

  @override
  Widget build(BuildContext context) => AppMotionBuilder(
    end: selected ? 1 : 0,
    builder: (context, t, _) => SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _GlyphPainter(
          symbol: symbol,
          t: t,
          ink: ink,
          cutout: cutout,
          repaint: repaint,
        ),
      ),
    ),
  );
}

class _GlyphPainter extends CustomPainter {
  _GlyphPainter({
    required this.symbol,
    required this.t,
    required this.ink,
    required this.cutout,
    super.repaint,
  });

  final TabSymbol symbol;
  final double t;
  final ValueGetter<Color> ink;
  final Color cutout;

  static const _box = 24.0;
  static const _stroke = 1.7;

  static Paint _stroked(Color color) => Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = _stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / _box);
    final color = ink();
    final fill = t.clamp(0.0, 1.0);
    // The gesture: zero at rest and settled, largest mid-flight.
    final gesture = sin(pi * fill);
    final line = _stroked(color);
    final solid = Paint()..color = color.withValues(alpha: color.a * fill);
    final cut = _stroked(cutout.withValues(alpha: cutout.a * fill));

    switch (symbol) {
      case TabSymbol.explore:
        _compass(canvas, fill, line, solid, cut);
      case TabSymbol.map:
        _map(canvas, gesture, line, solid, cut);
      case TabSymbol.trips:
        _case(canvas, gesture, line, solid, cut);
      case TabSymbol.profile:
        _person(canvas, fill, gesture, line);
      case TabSymbol.search:
        _magnifier(canvas, line);
    }
  }

  /// Search: a lens and its handle, the lens centred a little up and left
  /// so the whole glyph sits on the same optical centre as the others.
  void _magnifier(Canvas canvas, Paint line) {
    canvas.drawCircle(const Offset(10.5, 10.5), 6.5, line);
    canvas.drawLine(const Offset(15.2, 15.2), const Offset(20, 20), line);
  }

  void _compass(
    Canvas canvas,
    double fill,
    Paint line,
    Paint solid,
    Paint cut,
  ) {
    const centre = Offset(12, 12);
    canvas.drawCircle(centre, 9, line);
    canvas.drawCircle(centre, 9, solid);
    final needle = Path()
      ..moveTo(15.5, 8.5)
      ..lineTo(13.5, 13.5)
      ..lineTo(8.5, 15.5)
      ..lineTo(10.5, 10.5)
      ..close();
    canvas.save();
    // A half turn lands the diamond on itself, so the settled needle is the
    // outline's needle.
    canvas.translate(centre.dx, centre.dy);
    canvas.rotate(pi * fill);
    canvas.translate(-centre.dx, -centre.dy);
    // Outline: the needle in the glyph's colour; filled: cut out of the disc.
    final ink = line.color;
    canvas.drawPath(
      needle,
      _stroked(ink.withValues(alpha: ink.a * (1 - fill))),
    );
    canvas.drawPath(needle, Paint()..color = cut.color);
    canvas.restore();
  }

  void _map(Canvas canvas, double gesture, Paint line, Paint solid, Paint cut) {
    // Folded in a little mid-flight, open again once settled.
    canvas.save();
    canvas.translate(12, 12);
    canvas.scale(1 - 0.22 * gesture, 1);
    canvas.translate(-12, -12);
    final sheet = Path()
      ..moveTo(3, 6.5)
      ..lineTo(9, 4)
      ..lineTo(15, 6.5)
      ..lineTo(21, 4)
      ..lineTo(21, 18)
      ..lineTo(15, 20.5)
      ..lineTo(9, 18)
      ..lineTo(3, 20.5)
      ..close();
    canvas.drawPath(sheet, solid);
    canvas.drawPath(sheet, line);
    final folds = Path()
      ..moveTo(9, 4)
      ..lineTo(9, 18)
      ..moveTo(15, 6.5)
      ..lineTo(15, 20.5);
    canvas.drawPath(folds, line);
    canvas.drawPath(folds, cut);
    canvas.restore();
  }

  void _case(
    Canvas canvas,
    double gesture,
    Paint line,
    Paint solid,
    Paint cut,
  ) {
    final body = RRect.fromLTRBR(3, 7.5, 21, 19.5, const Radius.circular(3));
    canvas.drawRRect(body, solid);
    canvas.drawRRect(body, line);
    canvas.drawLine(const Offset(3.5, 12.5), const Offset(20.5, 12.5), cut);
    // The handle lifts a point and a half, like a lid opening.
    final handle = Path()
      ..moveTo(9, 7.5)
      ..lineTo(9, 6)
      ..arcToPoint(const Offset(11, 4), radius: const Radius.circular(2))
      ..lineTo(13, 4)
      ..arcToPoint(const Offset(15, 6), radius: const Radius.circular(2))
      ..lineTo(15, 7.5);
    canvas.save();
    canvas.translate(0, -1.5 * gesture);
    canvas.drawPath(handle, line);
    canvas.restore();
  }

  void _person(Canvas canvas, double fill, double gesture, Paint line) {
    // Head first, then the shoulders: the fill runs down the figure.
    final head = (fill * 2).clamp(0.0, 1.0);
    final body = (fill * 2 - 1).clamp(0.0, 1.0);
    final ink = line.color;
    canvas.save();
    canvas.translate(0, -gesture);
    final headCentre = const Offset(12, 8);
    canvas.drawCircle(headCentre, 3.6, line);
    canvas.drawCircle(
      headCentre,
      3.6,
      Paint()..color = ink.withValues(alpha: ink.a * head),
    );
    canvas.restore();
    final shoulders = Path()
      ..moveTo(5, 20)
      ..cubicTo(6.4, 16.4, 9, 14.8, 12, 14.8)
      ..cubicTo(15, 14.8, 17.6, 16.4, 19, 20);
    canvas.drawPath(
      Path.from(shoulders)..close(),
      Paint()..color = ink.withValues(alpha: ink.a * body),
    );
    canvas.drawPath(shoulders, line);
  }

  @override
  bool shouldRepaint(_GlyphPainter old) =>
      old.t != t ||
      old.ink != ink ||
      old.cutout != cutout ||
      old.symbol != symbol;
}
