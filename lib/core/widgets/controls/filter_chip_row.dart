import "package:flutter/material.dart";

import "../../theme/app_dimens.dart";
import "../../theme/app_icons.dart";
import "../../theme/app_typography.dart";
import "../motion/motion.dart";

/// One single-select chip in a [FilterChipRow].
class FilterChipItem {
  const FilterChipItem({
    required this.label,
    required this.selected,
    required this.onTap,
    this.onRemove,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  /// A filter that came from elsewhere (a town picked on Explore) and has no
  /// other chip to undo it: shown chosen, with the conventional close glyph
  /// trailing, the pair being as settled as trash beside Delete (doc 06).
  final VoidCallback? onRemove;
}

/// A horizontal row of single-select chips (the Map's and Browse's category
/// filters). Selection is solid green with white text, the theme's chip.
///
/// **Height.** [AppSize.chip] at the default text size, and taller by
/// exactly what a larger label needs: the label line is scaled on its own
/// (non-linear font scaling) and rounded up, so the chips are never cut off
/// at the bottom of the row.
class FilterChipRow extends StatelessWidget {
  const FilterChipRow({required this.items, super.key});

  final List<FilterChipItem> items;

  @override
  Widget build(BuildContext context) {
    final label = AppTypography.labelMedium;
    final grows =
        MediaQuery.textScalerOf(context).lineHeightOf(label) -
        label.fontSize! * label.height!;
    final height = (AppSize.chip + (grows > 0 ? grows : 0)).ceilToDouble();

    return SizedBox(
      height: height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.gutter),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpace.x2),
        itemBuilder: (context, index) {
          final item = items[index];
          final remove = item.onRemove;
          return Pressable(
            child: remove == null
                ? ChoiceChip(
                    label: Text(item.label),
                    selected: item.selected,
                    onSelected: (_) => item.onTap(),
                  )
                : InputChip(
                    label: Text(item.label),
                    selected: true,
                    showCheckmark: false,
                    onPressed: item.onTap,
                    onDeleted: remove,
                    deleteIcon: Icon(
                      AppIcons.close,
                      size: AppSize.glyphSm,
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                    deleteButtonTooltipMessage: "Clear ${item.label}",
                  ),
          );
        },
      ),
    );
  }
}
