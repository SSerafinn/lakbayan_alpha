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

/// A horizontal row of single-select chips (the Map's and Browse's filters).
/// White with a hairline at rest; the chosen chip fills emerald itself, on the
/// chip's own animation, so it cannot be left unpainted (D-19).
///
/// **Height.** [AppSize.chip] at the default text size, and taller by
/// exactly what a larger label needs, so a chip is never cut off.
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
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsetsDirectional.only(
          start: AppSpace.gutter,
          end: AppSpace.gutter,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (index, item) in items.indexed) ...[
              if (index > 0) const SizedBox(width: AppSpace.near),
              _Chip(item: item),
            ],
          ],
        ),
      ),
    );
  }
}

/// One chip, the theme's: white with the hairline, solid emerald when chosen.
class _Chip extends StatelessWidget {
  const _Chip({required this.item});

  final FilterChipItem item;

  @override
  Widget build(BuildContext context) {
    final remove = item.onRemove;
    final label = Text(item.label);
    return Pressable(
      child: remove == null
          ? ChoiceChip(
              label: label,
              selected: item.selected,
              onSelected: (_) => item.onTap(),
            )
          : InputChip(
              label: label,
              selected: true,
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
  }
}
