import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../../core/models/destination.dart";
import "../../../core/theme/app_dimens.dart";
import "../../../core/theme/app_icons.dart";
import "../../../core/theme/app_typography.dart";
import "../../../core/theme/lakbayan_colors.dart";
import "../../../core/widgets/cross_glyph.dart";
import "../domain/destination_providers.dart";

/// Home's category strip: one glyph circle per category, the label under it.
///
/// Confined to Home by agreement with the product owner (it breaks the
/// "no icon on everything" rule on purpose). The glyph colour is the
/// category's identity; selection still looks like solid green.
class CategoryStrip extends ConsumerWidget {
  const CategoryStrip({super.key});

  /// Food is deliberately not here: it is a place to eat, not a place to
  /// see, and the strip is about where to go.
  static const _categories = [
    DestinationCategory.nature,
    DestinationCategory.church,
    DestinationCategory.heritage,
    DestinationCategory.museum,
    DestinationCategory.landmark,
  ];

  static const _glyphSize = 25.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(homeCategoryProvider);
    return SizedBox(
      height: AppSize.glyphCircle + AppSpace.x1 + AppSpace.x4,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.gutter),
        itemCount: _categories.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpace.x3),
        itemBuilder: (context, index) {
          final category = _categories[index];
          return _CategoryItem(
            category: category,
            selected: category == selected,
            onTap: () =>
                ref.read(homeCategoryProvider.notifier).toggle(category),
          );
        },
      ),
    );
  }
}

class _CategoryItem extends StatelessWidget {
  const _CategoryItem({
    required this.category,
    required this.selected,
    required this.onTap,
  });

  final DestinationCategory category;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final brand = context.lakbayan;
    final glyphColor = selected
        ? scheme.onPrimary
        : brand.categoryColor(category);
    final glyph = AppIcons.forCategory(category);
    return Semantics(
      button: true,
      selected: selected,
      label: category.label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: SizedBox(
          width: AppSize.glyphCircle + AppSpace.x2,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: AppSize.glyphCircle,
                height: AppSize.glyphCircle,
                decoration: ShapeDecoration(
                  color: selected ? scheme.primary : scheme.surfaceContainerLow,
                  shape: const CircleBorder(),
                ),
                // Church is the one drawn glyph; see AppIcons.
                child: glyph == null
                    ? Center(
                        child: CrossGlyph(
                          size: CategoryStrip._glyphSize,
                          color: glyphColor,
                        ),
                      )
                    : Icon(
                        glyph,
                        size: CategoryStrip._glyphSize,
                        color: glyphColor,
                      ),
              ),
              const SizedBox(height: AppSpace.x1),
              Text(
                category.label,
                style: AppTypography.glyphLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
