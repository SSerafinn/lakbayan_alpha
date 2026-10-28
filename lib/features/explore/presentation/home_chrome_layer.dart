import "dart:async";

import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../../core/theme/app_dimens.dart";
import "../../../core/widgets/chrome/floating_tab_bar.dart";
import "../../../core/widgets/chrome/system_bars.dart";
import "../../destinations/domain/destination_providers.dart";
import "../domain/home_chrome.dart";
import "../domain/home_tab.dart";
import "search_surface.dart";

/// The home shell's chrome over the tab content: the ground under the
/// status bar, the floating tab bar at the bottom, and search, which grows
/// out of the bar's search cell and owns the screen while it is open (D-16). Search is an interrupting task
/// presented from its source (design doc 04); the three ways out (close
/// glyph, back, a picked row) retrace the one `t`.
///
/// In the Scaffold body rather than its bottom slot so the bar and the
/// search field ride the keyboard and the tab content never reflows.
class HomeChromeLayer extends ConsumerStatefulWidget {
  const HomeChromeLayer({required this.tab, required this.child, super.key});

  final HomeTab tab;

  /// The selected tab's content, under the chrome.
  final Widget child;

  @override
  ConsumerState<HomeChromeLayer> createState() => _HomeChromeLayerState();
}

class _HomeChromeLayerState extends ConsumerState<HomeChromeLayer> {
  bool _open = false;
  Rect? _origin;
  final _controller = TextEditingController();
  final _searchKey = GlobalKey();

  /// Typing held back until it pauses, as the wireframe asks.
  ///
  /// The field shows every letter at once; only the query waits. Without it
  /// each keystroke re-sorted the matches and replayed their entrance, so
  /// "callao" was six searches and six staggered animations — on the
  /// low-end phones this app is for, that is the jank. Browse had exactly
  /// this before search moved here in #77, and lost it in the move.
  Timer? _debounce;

  /// Long enough that a word is one search, short enough not to feel like
  /// waiting. Declared here because nothing else uses it.
  static const _settle = Duration(milliseconds: 250);

  void _onQuery(String value) {
    _debounce?.cancel();
    _debounce = Timer(_settle, () {
      if (mounted) ref.read(homeQueryProvider.notifier).update(value);
    });
  }

  /// Reads where the search cell is now (the bar may be shrunk), in this
  /// layer's space, so the field lifts out of exactly that spot: drawn in
  /// by the capsule's inset, a pill inside the bar.
  void _openSearch() {
    final cell = _searchKey.currentContext?.findRenderObject() as RenderBox?;
    final layer = context.findRenderObject() as RenderBox?;
    if (cell != null && layer != null && cell.hasSize) {
      final topLeft = layer.globalToLocal(cell.localToGlobal(Offset.zero));
      final bottomRight = layer.globalToLocal(
        cell.localToGlobal(cell.size.bottomRight(Offset.zero)),
      );
      final inset =
          TabBarLayout.inset * (bottomRight.dy - topLeft.dy) / cell.size.height;
      _origin = Rect.fromPoints(topLeft, bottomRight).deflate(inset);
    }
    setState(() => _open = true);
  }

  void _close() {
    if (_open) setState(() => _open = false);
  }

  /// Folded back into the cell: forget what was typed and chosen.
  void _forget() {
    // First: a keystroke still waiting would otherwise land after the clear
    // and bring the old query back into a search nobody has open.
    _debounce?.cancel();
    _controller.clear();
    ref.read(homeQueryProvider.notifier).update("");
    ref.read(searchCategoryProvider.notifier).clear();
  }

  @override
  void didUpdateWidget(HomeChromeLayer old) {
    super.didUpdateWidget(old);
    if (widget.tab != old.tab) _close();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_open,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) _close();
    },
    child: Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        // Every tab's content scrolls under this, never under the clock.
        const StatusBarGround(),
        _TabBarSlot(
          tab: widget.tab,
          searchOpen: _open,
          searchKey: _searchKey,
          onSearch: _openSearch,
        ),
        Positioned.fill(
          child: SearchSurface(
            open: _open,
            origin: _origin,
            controller: _controller,
            onChanged: _onQuery,
            onClose: _close,
            onFolded: _forget,
          ),
        ),
      ],
    ),
  );
}

/// The floating tab bar, pinned to the bottom. While search is open its
/// capsule slides away and the search cell hands its place to the field.
class _TabBarSlot extends ConsumerWidget {
  const _TabBarSlot({
    required this.tab,
    required this.searchOpen,
    required this.searchKey,
    required this.onSearch,
  });

  final HomeTab tab;
  final bool searchOpen;
  final GlobalKey searchKey;
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chrome = ref.watch(homeChromeProvider);
    // Clipped at the body's bottom edge so a hidden bar is truly off screen,
    // keyboard or not. Padding, not viewPadding: it is zero while the
    // keyboard is up.
    return Positioned(
      left: AppSpace.gutter,
      right: AppSpace.gutter,
      bottom: 0,
      child: ClipRect(
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.paddingOf(context).bottom + AppSpace.x3,
          ),
          child: FloatingTabBar(
            destinations: _tabs,
            selectedIndex: tab.index,
            collapsed: chrome == HomeChromeState.collapsed,
            hidden: chrome == HomeChromeState.hidden,
            searchOpen: searchOpen,
            searchKey: searchKey,
            onSearch: onSearch,
            onExpand: ref.read(homeChromeProvider.notifier).expand,
            // The shell resets the bar on every switch, however it came.
            onSelected: (i) => ref
                .read(selectedHomeTabProvider.notifier)
                .select(HomeTab.values[i]),
          ),
        ),
      ),
    );
  }
}

const _tabs = [
  AppDestination(symbol: TabSymbol.explore, label: "Explore"),
  AppDestination(symbol: TabSymbol.map, label: "Map"),
  AppDestination(symbol: TabSymbol.trips, label: "Trips"),
  AppDestination(symbol: TabSymbol.profile, label: "Profile"),
];
