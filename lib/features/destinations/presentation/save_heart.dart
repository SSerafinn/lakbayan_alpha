import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../../core/theme/app_dimens.dart";
import "../../../core/theme/app_motion.dart";
import "../../../core/theme/app_icons.dart";
import "../../../core/theme/lakbayan_colors.dart";
import "../../../core/widgets/motion/motion.dart";
import "../domain/saved_destinations.dart";

/// Where the heart sits, which sets its size and surface.
enum SaveHeartStyle {
  /// A 48 glass circle over hero photography.
  hero,

  /// A 32 glass circle at the top-right of a media tile.
  tile,

  /// A bare glyph as a grouped row's trailing accessory, padded to 48.
  row,

  /// A bare glyph as one item of a `BarItemGroup.overMedia`, the group's
  /// item size, inked like the glyphs beside it.
  bar,
}

/// The save control. A filled red heart when saved (`LakbayanColors.save`),
/// an outline when not. The outline fills as it turns red ([SymbolSwap]);
/// saving pops the glyph a beat larger and back on `AppMotion.arrive`, and
/// unsaving lets it settle from a beat smaller, so either tap is felt as well
/// as seen. The control sinks under the finger ([Pressable]). It is always
/// its own tap target and never a row's only action.
class SaveHeart extends ConsumerWidget {
  const SaveHeart(this.destinationId, {required this.style, super.key});

  final String destinationId;
  final SaveHeartStyle style;

  // A save lands a beat larger and settles; an unsave settles from a beat
  // smaller. Only a change animates, so a heart that mounts saved sits still.
  static const _savePop = 1.35;
  static const _unsavePop = 0.85;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final brand = context.lakbayan;
    final id = destinationId;
    final saved = ref.watch(
      savedDestinationsProvider.select((ids) => ids.contains(id)),
    );

    final (double size, double glyph, Color? fill) = switch (style) {
      SaveHeartStyle.hero => (AppSize.heroSave, AppSize.glyphLg, brand.glass),
      SaveHeartStyle.tile => (AppSize.tileSave, AppSize.glyphSm, brand.glass),
      SaveHeartStyle.row => (AppSize.minTouchTarget, AppSize.glyph, null),
      SaveHeartStyle.bar => (AppSize.symbolButton, AppSize.glyph, null),
    };
    // In a bar group the heart reads as one of its glyphs: ink at rest.
    final rest = style == SaveHeartStyle.bar
        ? scheme.onSurface
        : scheme.onSurfaceVariant;

    return Pressable(
      child: IconButton(
        onPressed: () {
          final notifier = ref.read(savedDestinationsProvider.notifier);
          saved ? notifier.remove(id) : notifier.save(id);
        },
        tooltip: saved ? "Saved" : "Save",
        isSelected: saved,
        icon: SymbolSwap(
          saved ? AppIcons.favoriteFilled : AppIcons.favorite,
          size: glyph,
          color: saved ? brand.save : rest,
          growFrom: saved ? _savePop : _unsavePop,
          motion: AppMotion.arrive,
        ),
        style:
            IconButton.styleFrom(
              backgroundColor: fill,
              foregroundColor: rest,
              fixedSize: Size.square(size),
              minimumSize: Size.square(size),
              padding: EdgeInsets.zero,
              shape: const CircleBorder(),
              tapTargetSize:
                  style == SaveHeartStyle.tile || style == SaveHeartStyle.bar
                  ? MaterialTapTargetSize.padded
                  : MaterialTapTargetSize.shrinkWrap,
            ).copyWith(
              foregroundColor: WidgetStateProperty.resolveWith(
                (states) =>
                    states.contains(WidgetState.selected) ? brand.save : rest,
              ),
            ),
      ),
    );
  }
}
