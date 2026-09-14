import "package:flutter/material.dart";

import "../theme/app_dimens.dart";

/// One symbol-only action inside a [BarItemGroup].
///
/// [tooltip] is required, not optional: it is both the pointer tooltip and
/// the accessibility label, and a symbol without one is a defect (design doc
/// 06). The action must have a reliable shorthand; if the glyph needs
/// explaining, it should be a labelled button outside the group.
class BarItem {
  const BarItem({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
}

/// Related actions on one shared capsule (design doc 04, bars and grouping).
///
/// **Anatomy.** A container holding two to four symbol-only items.
///
/// **Shape.** Capsule. Items inside have no individual container; emphasis
/// comes from the group, not from per-button plates.
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
    : assert(
        items.length >= 2 && items.length <= 4,
        "A bar group holds two to four items; overflow goes to a menu.",
      );

  final List<BarItem> items;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: scheme.surfaceContainer,
      shape: capsule,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.x1),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final item in items)
              IconButton(
                icon: Icon(item.icon),
                tooltip: item.tooltip,
                onPressed: item.onPressed,
              ),
          ],
        ),
      ),
    );
  }
}
