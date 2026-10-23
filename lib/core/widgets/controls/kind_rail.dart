import "package:flutter/material.dart";

import "../../theme/app_dimens.dart";
import "../../theme/app_typography.dart";
import "../motion/motion.dart";

/// One kind in a [KindRail]: its picture (outline at rest, [selectedGlyph]
/// while chosen) over its name.
class KindRailItem {
  const KindRailItem({
    required this.label,
    required this.glyph,
    required this.selectedGlyph,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData glyph;
  final IconData selectedGlyph;
  final bool selected;
  final VoidCallback onTap;
}

/// The kinds of place as one row of glyphs over words, the category row every
/// travel app settles on: no pills and no photos inside controls. At rest the
/// glyph and name sit on the page in quiet ink; the chosen kind is a solid
/// emerald cell with its filled glyph and white name, filling on the chrome
/// spring (Explore, and a town's page with an All cell first).
///
/// **Height.** A glyph, a gap and the name's line, padded; taller by exactly
/// what a larger text size needs.
class KindRail extends StatelessWidget {
  const KindRail({required this.items, super.key});

  final List<KindRailItem> items;

  static const _glyph = AppSize.glyphXl;
  static const _minWidth = 72.0;

  @override
  Widget build(BuildContext context) {
    final line = MediaQuery.textScalerOf(context)
        .lineHeightOf(AppTypography.labelMedium);
    final height = (AppSpace.x3 * 2 + _glyph + AppSpace.x1 + line)
        .ceilToDouble();

    return SizedBox(
      height: height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.gutter),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpace.x1),
        itemBuilder: (context, index) => _Cell(item: items[index]),
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({required this.item});

  final KindRailItem item;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: item.selected,
      child: Pressable(
        child: AppMotionBuilder(
          end: item.selected ? 1 : 0,
          builder: (context, t, _) {
            // A spring overshoots; a colour must not.
            final on = t.clamp(0.0, 1.0);
            final ink = Color.lerp(
              scheme.onSurfaceVariant,
              scheme.onPrimary,
              on,
            );
            return Material(
              color:
                  Color.lerp(Colors.transparent, scheme.primary, on) ??
                  Colors.transparent,
              shape: const RoundedRectangleBorder(borderRadius: AppRadii.mdAll),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: item.onTap,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minWidth: KindRail._minWidth,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpace.x3,
                      vertical: AppSpace.x3,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        FadeSwap(
                          id: item.selected,
                          child: Icon(
                            item.selected ? item.selectedGlyph : item.glyph,
                            size: KindRail._glyph,
                            color: ink,
                          ),
                        ),
                        const SizedBox(height: AppSpace.x1),
                        Text(
                          item.label,
                          style: AppTypography.labelMedium.copyWith(color: ink),
                          maxLines: 1,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
