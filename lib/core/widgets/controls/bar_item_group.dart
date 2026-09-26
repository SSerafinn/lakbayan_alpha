import "package:flutter/material.dart";

import "../../theme/app_dimens.dart";
import "../chrome/app_menu.dart";
import "symbol_button.dart";

/// One symbol-only action inside a [BarItemGroup].
///
/// [tooltip] is required, not optional: it is both the pointer tooltip and
/// the accessibility label, and a symbol without one is a defect (design doc
/// 06). The action must have a reliable shorthand; if the glyph needs
/// explaining, it should be a labelled button outside the group.
///
/// With [menu], the item opens an [AppMenu] of those groups, growing out of
/// the item's own glyph (the "more" at the end of a group); [onPressed] is
/// then unused.
///
/// [BarItem.control] is an item that is a control of its own and shows its
/// own state, such as the save heart: the group gives it a place and
/// nothing else. It carries its own tooltip and glyph size.
class BarItem {
  const BarItem({
    required IconData this.icon,
    required String this.tooltip,
    this.onPressed,
    this.menu,
  }) : control = null,
       assert(
         onPressed == null || menu == null,
         "An item either acts or opens a menu.",
       );

  const BarItem.control(Widget this.control)
    : icon = null,
      tooltip = null,
      onPressed = null,
      menu = null;

  final IconData? icon;
  final String? tooltip;
  final VoidCallback? onPressed;
  final List<List<AppMenuItem>>? menu;
  final Widget? control;
}

/// Related actions on one shared capsule (design doc 04, bars and grouping).
///
/// **Anatomy.** A container holding two to four symbol-only items.
///
/// **Shape.** Capsule. Items inside have no individual container; emphasis
/// comes from the group, not from per-button plates.
///
/// **Variants.** The default sits on the white ground on a grey capsule.
/// [BarItemGroup.overMedia] sits over a photo or a map on a white capsule,
/// sized with [SymbolButton] so a back circle beside it shares its height
/// (design doc 03: a control over content needs its own surface).
///
/// **Rules the widget enforces.** Two to four items (asserted). Symbols only:
/// there is no slot for a text label, so a labelled action cannot be dropped
/// in by accident. The primary action of a screen is never in a group; it
/// stands alone as the FAB.
///
/// **Behaviour.** Each item is independently activatable and meets the 48dp
/// minimum on its own; the group itself is not a target.
class BarItemGroup extends StatelessWidget {
  const BarItemGroup({required this.items, super.key})
    : overMedia = false,
      background = null,
      assert(
        items.length >= 2 && items.length <= 4,
        "A bar group holds two to four items; overflow goes to a menu.",
      );

  /// [background] replaces the white capsule's fill, for a group that
  /// passes from a photo onto the white page and takes the grey step up
  /// there, as [SymbolButton]'s `onGround` does.
  const BarItemGroup.overMedia({
    required this.items,
    this.background,
    super.key,
  }) : overMedia = true,
       assert(
         items.length >= 2 && items.length <= 4,
         "A bar group holds two to four items; overflow goes to a menu.",
       );

  final List<BarItem> items;
  final bool overMedia;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    Widget button(BarItem item, VoidCallback? onPressed) => IconButton(
      icon: Icon(item.icon!, size: overMedia ? AppSize.glyph : null),
      tooltip: item.tooltip,
      onPressed: onPressed,
      style: overMedia
          ? IconButton.styleFrom(
              foregroundColor: scheme.onSurface,
              fixedSize: const Size.square(AppSize.symbolButton),
            )
          : null,
    );

    return Material(
      color:
          background ?? (overMedia ? scheme.surface : scheme.surfaceContainer),
      shape: capsule,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: overMedia ? 0 : AppSpace.x1),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final item in items)
              if (item.control case final control?)
                control
              else if (item.menu case final menu?)
                AppMenu(
                  groups: menu,
                  builder: (context, controller) => button(
                    item,
                    controller.isOpen ? controller.close : controller.open,
                  ),
                )
              else
                button(item, item.onPressed),
          ],
        ),
      ),
    );
  }
}
