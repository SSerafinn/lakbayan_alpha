import "package:flutter/material.dart";

import "../../theme/app_dimens.dart";
import "../../theme/app_icons.dart";
import "../../theme/app_typography.dart";

/// Grouped rows on one white card, with an optional small heading over it.
/// No dividers between rows: the card is the grouping (D-19).
class GroupedSection extends StatelessWidget {
  const GroupedSection({required this.children, this.heading, super.key});

  final List<Widget> children;
  final String? heading;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final card = Material(
      color: scheme.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(borderRadius: AppRadii.mdAll),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.groupInset),
        child: ParentRadius(
          radius: _rowRadius,
          child: Column(mainAxisSize: MainAxisSize.min, children: children),
        ),
      ),
    );
    if (heading == null) return card;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.x1,
            0,
            AppSpace.x1,
            AppSpace.near,
          ),
          child: Text(
            heading!,
            style: AppTypography.groupHeading.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
        card,
      ],
    );
  }
}

/// A [GroupedSection] as a sliver: the same card, and only the rows on
/// screen are built.
class SliverGroupedSection extends StatelessWidget {
  const SliverGroupedSection({
    required this.itemCount,
    required this.itemBuilder,
    super.key,
  });

  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;

  @override
  Widget build(BuildContext context) => DecoratedSliver(
    decoration: ShapeDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(borderRadius: AppRadii.mdAll),
    ),
    sliver: SliverPadding(
      padding: const EdgeInsets.all(AppSpace.groupInset),
      sliver: SliverList.builder(
        itemCount: itemCount,
        itemBuilder: (context, index) => ParentRadius(
          radius: _rowRadius,
          child: Material(
            type: MaterialType.transparency,
            child: itemBuilder(context, index),
          ),
        ),
      ),
    ),
  );
}

/// A row's pressed shape, concentric with the card around it, so the photo
/// inside derives its corner in turn.
final _rowRadius = concentricRadius(
  parentRadius: AppRadii.md,
  padding: AppSpace.groupInset,
  fallback: AppRadii.sm,
);

/// One row: an optional mark (a stop's numeral), leading media or glyph,
/// title, second line, trailing accessory (a chevron when the row
/// navigates). The whole row is the target; a trailing accessory is its own
/// 48dp target only when it does something distinct, and every accessory
/// sits centred in one slot at least 48dp wide so they share an axis.
///
/// Compact by default: a [AppSize.rowMedia] photo and a one-line second
/// label keep a row near 60dp. [dense] is smaller still, for sheet pickers.
/// A row with nothing leading insets its words further, as a settings row.
class GroupedRow extends StatelessWidget {
  const GroupedRow({
    required this.title,
    this.subtitle,
    this.subtitleColor,
    this.mark,
    this.leading,
    this.leadingGlyph,
    this.glyphColor,
    this.trailing,
    this.onTap,
    this.dense = false,
    super.key,
  }) : assert(
         leading == null || leadingGlyph == null,
         "A row leads with media or a glyph, not both.",
       );

  final String title;
  final String? subtitle;

  /// Colours the second line when it carries a role (a distance in blue).
  final Color? subtitleColor;

  /// Before the media: a stop's numeral, or an empty box of its width so a
  /// row without one lines up.
  final Widget? mark;

  /// Raw media; sized and clipped here.
  final Widget? leading;
  final IconData? leadingGlyph;
  final Color? glyphColor;

  /// Replaces the default chevron. Pass [noAccessory] for none.
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool dense;

  /// A navigating row with nothing trailing: no chevron, no slot.
  static const Widget noAccessory = SizedBox.shrink();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final mediaSize = dense ? AppSize.rowMediaDense : AppSize.rowMedia;
    final bare = mark == null && leading == null && leadingGlyph == null;
    final padding = EdgeInsets.symmetric(
      horizontal: bare ? AppSpace.x3 : AppSpace.near,
      vertical: dense ? AppSpace.x1 : AppSpace.near,
    );
    final rowRadius = ParentRadius.maybeOf(context) ?? AppRadii.sm;
    final mediaRadius = concentricRadius(
      parentRadius: rowRadius,
      padding: padding.left,
      fallback: AppRadii.xs,
    );

    final Widget? accessory = identical(trailing, noAccessory)
        ? null
        : trailing ??
              (onTap == null
                  ? null
                  : Icon(
                      AppIcons.chevron,
                      size: AppSize.glyphMd,
                      color: scheme.onSurfaceVariant,
                    ));

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(rowRadius),
      child: Padding(
        padding: padding,
        child: Row(
          children: [
            if (mark != null) ...[mark!, const SizedBox(width: AppSpace.x3)],
            if (leading != null) ...[
              SizedBox(
                width: mediaSize,
                height: mediaSize,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(mediaRadius),
                  child: ParentRadius(radius: mediaRadius, child: leading!),
                ),
              ),
              const SizedBox(width: AppSpace.x3),
            ],
            if (leadingGlyph != null) ...[
              SizedBox.square(
                dimension: mediaSize,
                child: DecoratedBox(
                  // Paper inside the card, never grey on grey.
                  decoration: ShapeDecoration(
                    color: scheme.surfaceContainerLow,
                    shape: const CircleBorder(),
                  ),
                  child: Icon(
                    leadingGlyph,
                    size: AppSize.glyphLg,
                    color: glyphColor ?? scheme.onSurface,
                  ),
                ),
              ),
              const SizedBox(width: AppSpace.x3),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: AppTypography.titleSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: AppTypography.secondLine.copyWith(
                        color: subtitleColor ?? scheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            if (accessory != null) ...[
              const SizedBox(width: AppSpace.x2),
              // One 48dp slot, and no narrower, so lone accessories share an
              // axis; a cluster of controls (a stop row while reordering)
              // widens it rather than overflowing the row.
              ConstrainedBox(
                constraints: const BoxConstraints(
                  minWidth: AppSize.minTouchTarget,
                  minHeight: AppSize.minTouchTarget,
                  maxHeight: AppSize.minTouchTarget,
                ),
                child: Center(child: accessory),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
