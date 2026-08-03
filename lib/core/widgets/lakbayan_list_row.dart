import "package:flutter/material.dart";

import "../theme/app_dimens.dart";
import "../theme/app_typography.dart";
import "../theme/lakbayan_colors.dart";
import "lakbayan_badge.dart";

/// The list row from the design system: 56dp thumbnail, title, subtitle, and
/// either a chevron or a trailing badge.
///
/// The [selected] state fills with green/50 and rounds to 12dp — the same tint
/// used for a selected bottom-nav destination, so "current" reads consistently
/// across the app.
class LakbayanListRow extends StatelessWidget {
  const LakbayanListRow({
    required this.title,
    required this.subtitle,
    this.leading,
    this.trailing,
    this.selected = false,
    this.showDivider = true,
    this.onTap,
    super.key,
  });

  final String title;
  final String subtitle;

  /// 56×56 thumbnail. Defaults to a placeholder.
  final Widget? leading;

  /// Defaults to a chevron. Pass a [LakbayanBadge] for rows that carry status.
  final Widget? trailing;

  final bool selected;
  final bool showDivider;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.lakbayan;

    final row = Container(
      decoration: BoxDecoration(
        color: selected ? c.greenSubtle : null,
        borderRadius: selected ? AppRadius.mdAll : null,
      ),
      padding: const EdgeInsets.symmetric(
        vertical: AppSpace.x3,
        horizontal: AppSpace.x1,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 56,
            height: 56,
            child: leading ?? const ImagePlaceholder(),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: AppTypography.title.copyWith(
                    color: selected ? c.textOnLightGreen : null,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: AppTypography.body.copyWith(
                    color: selected ? null : c.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpace.x2),
          trailing ??
              Icon(Icons.chevron_right, color: c.textDisabled, size: 22),
        ],
      ),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 48dp minimum touch target is satisfied by the 56dp thumbnail plus
        // vertical padding; InkWell covers the whole row.
        Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            borderRadius: AppRadius.mdAll,
            child: row,
          ),
        ),
        if (showDivider && !selected) Divider(color: c.line, height: 1),
      ],
    );
  }
}
