import "package:flutter/material.dart";

import "../../../core/models/destination.dart";
import "../../../core/theme/app_dimens.dart";
import "../../../core/theme/app_icons.dart";
import "../../../core/theme/app_motion.dart";
import "../../../core/widgets/content/grouped_section.dart";
import "../../../core/widgets/content/storage_image.dart";
import "../../../core/widgets/motion/motion.dart";

/// Places as selectable rows: thumbnail, name, town, and a selection circle
/// on the trailing edge, solid green with a white check when chosen and an
/// empty hairline circle when not. Selection is a shape change plus colour,
/// never colour alone.
///
/// A sliver: the list is every published place, so only rows on screen are built.
class SliverStopPicker extends StatelessWidget {
  const SliverStopPicker({
    required this.items,
    required this.selected,
    required this.onToggle,
    super.key,
  });

  final List<Destination> items;
  final Set<String> selected;
  final ValueChanged<Destination> onToggle;

  @override
  Widget build(BuildContext context) => SliverGroupedSection(
    itemCount: items.length,
    itemBuilder: (context, index) {
      final place = items[index];
      return GroupedRow(
        title: place.name,
        subtitle: place.town,
        leading: CoverImage(place.coverImage),
        trailing: SelectionCircle(selected: selected.contains(place.id)),
        onTap: () => onToggle(place),
      );
    },
  );
}

/// The trailing check of a selectable row. Choosing fills the circle green
/// and pops the check in on `AppMotion.arrive`; clearing drains it again.
class SelectionCircle extends StatelessWidget {
  const SelectionCircle({required this.selected, super.key});

  final bool selected;

  static const _size = AppSize.selectionCircle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AppMotionBuilder(
      end: selected ? 1 : 0,
      motion: AppMotion.arrive,
      builder: (context, t, _) {
        // The spring overshoots; the colours may not.
        final fill = t.clamp(0.0, 1.0);
        return Container(
          width: _size,
          height: _size,
          margin: const EdgeInsets.only(right: AppSpace.x1),
          decoration: ShapeDecoration(
            color: scheme.primary.withValues(alpha: fill),
            shape: CircleBorder(
              side: BorderSide(
                color: scheme.outlineVariant.withValues(alpha: 1 - fill),
                width: AppStroke.regular,
              ),
            ),
          ),
          child: t <= 0
              ? null
              : Transform.scale(
                  scale: t,
                  child: Icon(
                    AppIcons.check,
                    size: AppSize.glyphSm,
                    color: scheme.onPrimary,
                  ),
                ),
        );
      },
    );
  }
}
