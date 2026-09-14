import "package:flutter/material.dart";

import "../../../core/models/destination.dart";
import "../../../core/theme/app_dimens.dart";
import "../../../core/theme/app_icons.dart";
import "../../../core/widgets/grouped_section.dart";
import "../../../core/widgets/storage_image.dart";

/// Places as selectable rows: thumbnail, name, town, and a selection circle
/// on the trailing edge, solid green with a white check when chosen and an
/// empty hairline circle when not. Selection is a shape change plus colour,
/// never colour alone.
class StopPicker extends StatelessWidget {
  const StopPicker({
    required this.items,
    required this.selected,
    required this.onToggle,
    super.key,
  });

  final List<Destination> items;
  final Set<String> selected;
  final ValueChanged<Destination> onToggle;

  @override
  Widget build(BuildContext context) => GroupedSection(
    children: [
      for (final place in items)
        GroupedRow(
          title: place.name,
          subtitle: place.town,
          leading: CoverImage(place.coverImage),
          trailing: SelectionCircle(selected: selected.contains(place.id)),
          onTap: () => onToggle(place),
        ),
    ],
  );
}

/// The trailing check of a selectable row.
class SelectionCircle extends StatelessWidget {
  const SelectionCircle({required this.selected, super.key});

  final bool selected;

  static const _size = 26.0;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: _size,
      height: _size,
      margin: const EdgeInsets.only(right: AppSpace.x1),
      decoration: ShapeDecoration(
        color: selected ? scheme.primary : null,
        shape: CircleBorder(
          side: selected
              ? BorderSide.none
              : BorderSide(color: scheme.outlineVariant, width: 1.5),
        ),
      ),
      child: selected
          ? Icon(AppIcons.check, size: 16, color: scheme.onPrimary)
          : null,
    );
  }
}
