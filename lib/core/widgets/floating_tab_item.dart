import "package:flutter/material.dart";

import "../theme/app_dimens.dart";
import "../theme/app_typography.dart";
import "app_destination.dart";

/// A single destination item within `FloatingTabBar`.
///
/// Renders an icon and optional label with continuous cross-fade and height
/// interpolation based on [selectionAmount] (0.0 to 1.0) and [expansion]
/// (0.0 for collapsed glyph capsule, 1.0 for full resting capsule).
class FloatingTabItem extends StatelessWidget {
  const FloatingTabItem({
    required this.destination,
    required this.selectionAmount,
    required this.expansion,
    required this.onTap,
    this.labelGap = 2.0,
    super.key,
  });

  final AppDestination destination;
  final double selectionAmount;
  final double expansion;
  final VoidCallback onTap;
  final double labelGap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isSelected = selectionAmount >= 0.5;

    final contentColor = Color.lerp(
      scheme.onSurfaceVariant,
      scheme.onPrimary,
      selectionAmount,
    )!;

    final iconData = isSelected ? destination.selectedIcon : destination.icon;

    final baseStyle = isSelected
        ? AppTypography.tabLabelSelected
        : AppTypography.tabLabel;
    final labelStyle = baseStyle.copyWith(color: contentColor);

    final content = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(iconData, size: AppSize.tabGlyph, color: contentColor),
        if (expansion > 0) ...[
          SizedBox(height: labelGap * expansion),
          ClipRect(
            child: Align(
              heightFactor: expansion,
              // The spring overshoots; opacity may not.
              child: Opacity(
                opacity: expansion.clamp(0.0, 1.0),
                child: Text(
                  destination.label,
                  style: labelStyle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
        ],
      ],
    );

    final item = Semantics(
      button: true,
      selected: isSelected,
      label: destination.label,
      excludeSemantics: true,
      child: InkWell(
        customBorder: capsule,
        onTap: onTap,
        child: SizedBox.expand(child: Center(child: content)),
      ),
    );

    return expansion == 0
        ? Tooltip(
            message: destination.label,
            excludeFromSemantics: true,
            child: item,
          )
        : item;
  }
}
