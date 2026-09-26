import "package:flutter/material.dart";

import "../../theme/app_dimens.dart";
import "../../theme/app_icons.dart";
import "../../theme/app_typography.dart";

/// Grouped rows on the white ground with an optional heading.
/// No dividers between rows — grouping is the signal.
class GroupedSection extends StatelessWidget {
  const GroupedSection({required this.children, this.heading, super.key});

  final List<Widget> children;
  final String? heading;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      if (heading != null)
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.x1,
            0,
            AppSpace.x1,
            AppSpace.x1,
          ),
          child: Text(heading!, style: AppTypography.groupHeading),
        ),
      ParentRadius(
        radius: _rowRadius,
        child: Column(mainAxisSize: MainAxisSize.min, children: children),
      ),
    ],
  );
}

/// A [GroupedSection] as a sliver: only rows on screen are built.
class SliverGroupedSection extends StatelessWidget {
  const SliverGroupedSection({
    required this.itemCount,
    required this.itemBuilder,
    super.key,
  });

  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;

  @override
  Widget build(BuildContext context) => SliverList.builder(
    itemCount: itemCount,
    itemBuilder: (context, index) => ParentRadius(
      radius: _rowRadius,
      child: Material(
        type: MaterialType.transparency,
        child: itemBuilder(context, index),
      ),
    ),
  );
}

/// A row's pressed shape: fixed, so the photo inside derives its corner.
const _rowRadius = AppRadii.md;

/// One row: an optional mark (a stop's numeral), leading media or glyph,
/// title, second line, trailing accessory (a chevron when the row
/// navigates). The whole row is the target; a trailing accessory is its own
/// 48dp target only when it does something distinct, and every accessory
/// sits centred in one slot at least 48dp wide so they share an axis.
///
/// Compact by default: a [AppSize.rowMedia] photo and a one-line second
/// label keep a row near 64dp. [dense] is smaller still, for sheet pickers.
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
    final padding = EdgeInsets.symmetric(
      horizontal: AppSpace.x1,
      vertical: dense ? AppSpace.x1 : AppSpace.rowPadDense,
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
                  decoration: ShapeDecoration(
                    color: scheme.surfaceContainerHigh,
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
