import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:motor/motor.dart";

import "../../../core/theme/app_dimens.dart";
import "../../../core/theme/app_motion.dart";
import "../../../core/theme/app_icons.dart";
import "../../../core/theme/lakbayan_colors.dart";
import "../domain/saved_destinations.dart";

/// Where the heart sits, which sets its size and surface.
enum SaveHeartStyle {
  /// A 48 white circle over hero photography.
  hero,

  /// A 32 white circle at the top-right of a media tile.
  tile,

  /// A bare glyph as a grouped row's trailing accessory, padded to 48.
  row,
}

/// The save control. A filled red heart when saved (`LakbayanColors.save`),
/// an outline when not. Saving pops the glyph, a beat larger and back, so
/// the tap is felt as well as seen. It is always its own tap target and
/// never a row's only action.
class SaveHeart extends ConsumerStatefulWidget {
  const SaveHeart(this.destinationId, {required this.style, super.key});

  final String destinationId;
  final SaveHeartStyle style;

  @override
  ConsumerState<SaveHeart> createState() => _SaveHeartState();
}

class _SaveHeartState extends ConsumerState<SaveHeart> {
  /// Only a save made here pops; a heart that mounts already saved does not.
  bool _justSaved = false;

  void _toggle(bool saved) {
    final notifier = ref.read(savedDestinationsProvider.notifier);
    if (saved) {
      notifier.remove(widget.destinationId);
      return;
    }
    notifier.save(widget.destinationId);
    _justSaved = !MediaQuery.disableAnimationsOf(context);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final brand = context.lakbayan;
    final id = widget.destinationId;
    final saved = ref.watch(
      savedDestinationsProvider.select((ids) => ids.contains(id)),
    );

    final (double size, double glyph, Color? fill) = switch (widget.style) {
      SaveHeartStyle.hero => (AppSize.heroSave, 22, scheme.surface),
      SaveHeartStyle.tile => (AppSize.tileSave, 16, scheme.surface),
      SaveHeartStyle.row => (AppSize.minTouchTarget, 20, null),
    };

    return IconButton(
      onPressed: () => _toggle(saved),
      tooltip: saved ? "Saved" : "Save",
      isSelected: saved,
      icon: Icon(AppIcons.favorite, size: glyph),
      selectedIcon: SingleMotionBuilder(
        motion: AppMotion.arrive,
        from: _justSaved ? 1.35 : null,
        value: 1,
        child: Icon(AppIcons.favoriteFilled, size: glyph),
        builder: (context, scale, child) =>
            Transform.scale(scale: scale, child: child),
      ),
      style:
          IconButton.styleFrom(
            backgroundColor: fill,
            foregroundColor: scheme.onSurfaceVariant,
            fixedSize: Size.square(size),
            minimumSize: Size.square(size),
            padding: EdgeInsets.zero,
            shape: const CircleBorder(),
            tapTargetSize: widget.style == SaveHeartStyle.tile
                ? MaterialTapTargetSize.padded
                : MaterialTapTargetSize.shrinkWrap,
          ).copyWith(
            foregroundColor: WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.selected)
                  ? brand.save
                  : scheme.onSurfaceVariant,
            ),
          ),
    );
  }
}
