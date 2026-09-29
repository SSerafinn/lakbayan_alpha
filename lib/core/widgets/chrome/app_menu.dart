import "dart:ui" show lerpDouble;

import "package:flutter/foundation.dart" show ValueListenable;
import "package:flutter/material.dart";

import "../../theme/app_dimens.dart";
import "../../theme/app_icons.dart";
import "../../theme/app_typography.dart";
import "../../theme/lakbayan_colors.dart";
import "../motion/motion.dart";

/// One action in an [AppMenu].
///
/// Label first, its glyph trailing on a shared axis, the way the reference
/// platform's menus read (doc 06, menus): every item carries a glyph so every
/// label starts on the same edge. [selected] is the optional leading slot, a
/// check for the chosen option in a menu of choices.
class AppMenuItem {
  const AppMenuItem({
    required this.label,
    required this.icon,
    required this.onSelected,
    this.destructive = false,
    this.selected,
  });

  final String label;
  final IconData icon;
  final VoidCallback onSelected;

  /// Red label and glyph. Only in the last group, and only with a glyph that
  /// says the same thing (the trash), so colour is never the only signal.
  final bool destructive;

  /// Null for an action; true or false for an option in a menu of choices.
  final bool? selected;
}

/// A menu that grows out of the control that opened it and folds back into it
/// (design doc 04, source and presentation).
///
/// Built on [RawMenuAnchor], which keeps the anchoring, outside-tap and escape
/// dismissal, focus and semantics; this widget adds only the look and the
/// motion. Opening and closing ride one `t` on `AppMotion.chrome`, so a close
/// plays the same path backwards from wherever the open had got to, whether it
/// was closed by an item, a tap outside, or system back. Reduced motion
/// cross-fades.
///
/// [groups] are drawn as separate surfaces with a gap between them rather
/// than a divider; the last group is where a destructive action goes.
class AppMenu extends StatefulWidget {
  const AppMenu({required this.groups, required this.builder, super.key});

  final List<List<AppMenuItem>> groups;

  /// Builds the control that opens the menu. Call `controller.open`.
  final Widget Function(BuildContext context, MenuController controller)
  builder;

  @override
  State<AppMenu> createState() => _AppMenuState();
}

class _AppMenuState extends State<AppMenu> {
  final _controller = MenuController();

  /// Where the menu is heading: open or folded back into its source.
  final _open = ValueNotifier(false);

  /// The close that is waiting for the fold to finish.
  VoidCallback? _hide;

  @override
  void dispose() {
    _open.dispose();
    super.dispose();
  }

  void _onOpenRequested(Offset? _, VoidCallback showOverlay) {
    _hide = null;
    showOverlay();
    _open.value = true;
  }

  void _onCloseRequested(VoidCallback hideOverlay) {
    if (!_controller.isOpen) return hideOverlay();
    if (MediaQuery.disableAnimationsOf(context)) {
      _open.value = false;
      return hideOverlay();
    }
    _hide = hideOverlay;
    _open.value = false;
  }

  void _folded() {
    final hide = _hide;
    _hide = null;
    hide?.call();
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
    valueListenable: _open,
    // System back closes an open menu before it leaves the screen.
    builder: (context, open, child) => PopScope(
      canPop: !open,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _controller.close();
      },
      child: child!,
    ),
    child: RawMenuAnchor(
      controller: _controller,
      consumeOutsideTaps: true,
      onOpenRequested: _onOpenRequested,
      onCloseRequested: _onCloseRequested,
      builder: (context, controller, _) => widget.builder(context, controller),
      overlayBuilder: (context, info) => _MenuOverlay(
        info: info,
        open: _open,
        groups: widget.groups,
        controller: _controller,
        onFolded: _folded,
      ),
    ),
  );
}

class _MenuOverlay extends StatelessWidget {
  const _MenuOverlay({
    required this.info,
    required this.open,
    required this.groups,
    required this.controller,
    required this.onFolded,
  });

  final RawMenuOverlayInfo info;
  final ValueListenable<bool> open;
  final List<List<AppMenuItem>> groups;
  final MenuController controller;
  final VoidCallback onFolded;

  /// How small the menu starts, as a share of its size, at its source corner.
  static const _startScale = 0.6;

  @override
  Widget build(BuildContext context) {
    final anchor = info.anchorRect;
    final screen = info.overlaySize;
    final padding = MediaQuery.paddingOf(context);
    // Open toward the side with room, from the anchor's nearest corner.
    final leading = anchor.center.dx < screen.width / 2;
    final below = anchor.center.dy < screen.height / 2;
    final origin = Alignment(leading ? -1 : 1, below ? -1 : 1);

    final menu = TapRegion(
      groupId: info.tapRegionGroupId,
      // The anchor's own outside tap only closes submenus, and it swallows
      // the tap, so without this a tap anywhere else did nothing at all.
      // The panel closes the menu itself, as `RawMenuAnchor` documents.
      onTapOutside: (_) => controller.close(),
      child: _MenuBody(groups: groups, controller: controller),
    );

    return CustomSingleChildLayout(
      delegate: _MenuLayout(
        anchor: anchor,
        leading: leading,
        below: below,
        safe: padding,
      ),
      child: ValueListenableBuilder<bool>(
        valueListenable: open,
        child: menu,
        builder: (context, open, menu) => AppMotionBuilder(
          end: open ? 1 : 0,
          from: 0,
          onEnd: open ? null : onFolded,
          child: menu,
          builder: (context, t, menu) {
            if (t == 1) return menu!;
            final shown = t.clamp(0.0, 1.0);
            return IgnorePointer(
              ignoring: !open,
              child: Opacity(
                opacity: shown,
                child: Transform.scale(
                  scale: lerpDouble(_startScale, 1, t),
                  alignment: origin,
                  child: menu,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Places the menu under (or over) its anchor, aligned to the anchor's edge
/// on the side it opens from, and kept inside the safe area and the gutter.
class _MenuLayout extends SingleChildLayoutDelegate {
  const _MenuLayout({
    required this.anchor,
    required this.leading,
    required this.below,
    required this.safe,
  });

  final Rect anchor;
  final bool leading;
  final bool below;
  final EdgeInsets safe;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      BoxConstraints.loose(
        Size(
          constraints.maxWidth - AppSpace.gutter * 2,
          constraints.maxHeight - safe.vertical - AppSpace.gutter * 2,
        ),
      );

  @override
  Offset getPositionForChild(Size size, Size child) {
    final x = leading ? anchor.left : anchor.right - child.width;
    final y = below
        ? anchor.bottom + AppSpace.x2
        : anchor.top - AppSpace.x2 - child.height;
    return Offset(
      x.clamp(AppSpace.gutter, size.width - AppSpace.gutter - child.width),
      y.clamp(
        safe.top + AppSpace.gutter,
        size.height - safe.bottom - AppSpace.gutter - child.height,
      ),
    );
  }

  @override
  bool shouldRelayout(_MenuLayout old) =>
      anchor != old.anchor ||
      leading != old.leading ||
      below != old.below ||
      safe != old.safe;
}

class _MenuBody extends StatelessWidget {
  const _MenuBody({required this.groups, required this.controller});

  final List<List<AppMenuItem>> groups;
  final MenuController controller;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // A selection slot on one row means a slot on every row, so the labels
    // of a menu of choices share an edge.
    final choosing = groups.any((g) => g.any((i) => i.selected != null));

    return Semantics(
      explicitChildNodes: true,
      child: FocusTraversalGroup(
        child: SizedBox(
          width: AppSize.menuWidth,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final (index, group) in groups.indexed) ...[
                  if (index > 0) const SizedBox(height: AppSpace.menuGroupGap),
                  // Each group is its own fixed surface; rows run to its
                  // edges and its clip rounds their highlight, so the two
                  // are concentric by construction.
                  Material(
                    color: scheme.surfaceContainerHigh,
                    shape: const RoundedRectangleBorder(
                      borderRadius: AppRadii.mdAll,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final item in group)
                          _MenuRow(
                            item: item,
                            choosing: choosing,
                            autofocus: index == 0 && item == group.first,
                            onTap: () {
                              controller.close();
                              item.onSelected();
                            },
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.item,
    required this.choosing,
    required this.autofocus,
    required this.onTap,
  });

  final AppMenuItem item;
  final bool choosing;
  final bool autofocus;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colour = item.destructive
        ? context.lakbayan.closed
        : scheme.onSurface;

    return Semantics(
      button: true,
      selected: item.selected,
      child: InkWell(
        onTap: onTap,
        autofocus: autofocus,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppSize.minTouchTarget),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpace.x4,
              vertical: AppSpace.x3,
            ),
            child: Row(
              children: [
                if (choosing) ...[
                  SizedBox(
                    width: AppSize.glyph,
                    child: item.selected ?? false
                        ? Icon(
                            AppIcons.check,
                            size: AppSize.glyphMd,
                            color: scheme.onSurface,
                          )
                        : null,
                  ),
                  const SizedBox(width: AppSpace.x2),
                ],
                Expanded(
                  child: Text(
                    item.label,
                    style: AppTypography.labelLarge.copyWith(color: colour),
                  ),
                ),
                const SizedBox(width: AppSpace.x3),
                ExcludeSemantics(
                  child: Icon(item.icon, size: AppSize.glyph, color: colour),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
