import "package:flutter/material.dart";

import "../theme/app_dimens.dart";
import "../theme/app_icons.dart";
import "../theme/app_typography.dart";

/// Comparable rows on one shared surface, an optional heading above it.
/// Fixed [AppRadii.md]; rows derive their pressed radius through
/// [ParentRadius]. Nothing is drawn between rows: the surface says they
/// belong together (design doc 04), so there is no divider slot.
class GroupedSection extends StatelessWidget {
  const GroupedSection({required this.children, this.heading, super.key});

  final List<Widget> children;
  final String? heading;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const radius = AppRadii.md;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (heading != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.x1,
              0,
              AppSpace.x1,
              AppSpace.x2,
            ),
            child: Text(heading!, style: AppTypography.groupHeading),
          ),
        Material(
          color: scheme.surfaceContainerLow,
          shape: const RoundedRectangleBorder(borderRadius: AppRadii.mdAll),
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.groupInset),
            child: ParentRadius(
              radius: concentricRadius(
                parentRadius: radius,
                padding: AppSpace.groupInset,
                fallback: AppRadii.sm,
              ),
              child: Column(mainAxisSize: MainAxisSize.min, children: children),
            ),
          ),
        ),
      ],
    );
  }
}

/// One row of a [GroupedSection]: leading media or glyph, title, second
/// line, trailing accessory (a chevron when the row navigates). The whole row
/// is the target; a trailing accessory is its own 48dp target only when it
/// does something distinct, and every accessory sits centred in one slot at
/// least 48dp wide so they share an axis down the section. A glyph only where it maps to an
/// established action (save, download, play).
class GroupedRow extends StatelessWidget {
  const GroupedRow({
    required this.title,
    this.subtitle,
    this.subtitleColor,
    this.leading,
    this.leadingGlyph,
    this.glyphColor,
    this.trailing,
    this.onTap,
    super.key,
  }) : assert(
         leading == null || leadingGlyph == null,
         "A row leads with media or a glyph, not both.",
       );

  final String title;
  final String? subtitle;

  /// Colours the second line when it carries a role (a distance in blue).
  final Color? subtitleColor;

  /// Raw media; sized and clipped here.
  final Widget? leading;
  final IconData? leadingGlyph;
  final Color? glyphColor;

  /// Replaces the default chevron. Pass [noAccessory] for none.
  final Widget? trailing;
  final VoidCallback? onTap;

  /// A navigating row with nothing trailing: no chevron, no slot.
  static const Widget noAccessory = SizedBox.shrink();

  static const _mediaSize = 56.0;
  static const _glyphCircle = 40.0;
  static const _padding = EdgeInsets.all(AppSpace.rowPad);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final rowRadius = ParentRadius.maybeOf(context) ?? AppRadii.sm;
    final mediaRadius = concentricRadius(
      parentRadius: rowRadius,
      padding: _padding.left,
      fallback: AppRadii.xs,
    );

    final Widget? accessory = identical(trailing, noAccessory)
        ? null
        : trailing ??
              (onTap == null
                  ? null
                  : Icon(
                      AppIcons.chevron,
                      size: 18,
                      color: scheme.onSurfaceVariant,
                    ));

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(rowRadius),
      child: Padding(
        padding: _padding,
        child: Row(
          children: [
            if (leading != null) ...[
              SizedBox(
                width: _mediaSize,
                height: _mediaSize,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(mediaRadius),
                  child: ParentRadius(radius: mediaRadius, child: leading!),
                ),
              ),
              const SizedBox(width: AppSpace.x3),
            ],
            if (leadingGlyph != null) ...[
              SizedBox(
                width: _glyphCircle,
                height: _glyphCircle,
                child: DecoratedBox(
                  decoration: ShapeDecoration(
                    color: scheme.surfaceContainerHigh,
                    shape: const CircleBorder(),
                  ),
                  child: Icon(
                    leadingGlyph,
                    size: 22,
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
                      maxLines: 2,
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
