import "package:flutter/material.dart";
import "package:motor/motor.dart";

import "../../theme/app_dimens.dart";
import "../../theme/app_icons.dart";
import "../../theme/app_motion.dart";
import "../../theme/app_typography.dart";
import "../motion/motion.dart";

/// One single-select chip in a [FilterChipRow].
class FilterChipItem {
  const FilterChipItem({
    required this.label,
    required this.selected,
    required this.onTap,
    this.avatar,
    this.onRemove,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  /// A round photo before the label (Explore's kinds), so the kind is seen,
  /// not only named.
  final Widget? avatar;

  /// A filter that came from elsewhere (a town picked on Explore) and has no
  /// other chip to undo it: shown chosen, with the conventional close glyph
  /// trailing, the pair being as settled as trash beside Delete (doc 06).
  final VoidCallback? onRemove;
}

/// A horizontal row of single-select chips (Explore's kinds, the Map's and
/// Browse's filters). The emerald pill travels from the chosen chip to the
/// next on the chrome spring, painted behind the row, never rebuilt per
/// frame (D-19). White chips with a hairline at rest.
///
/// **Height.** [AppSize.chip] at the default text size, and taller by
/// exactly what a larger label needs, so a chip is never cut off.
class FilterChipRow extends StatefulWidget {
  const FilterChipRow({required this.items, super.key});

  final List<FilterChipItem> items;

  @override
  State<FilterChipRow> createState() => _FilterChipRowState();
}

class _FilterChipRowState extends State<FilterChipRow>
    with SingleTickerProviderStateMixin {
  final _row = GlobalKey();
  late List<GlobalKey> _chips = _keys();

  /// Where the pill travels from and to; [_to] is null while nothing is
  /// chosen. The painter repaints on either moving.
  Rect? _from;
  final _to = ValueNotifier<Rect?>(null);
  late final _travel = SingleMotionController(
    motion: AppMotion.chrome,
    vsync: this,
    initialValue: 1,
  );
  late final Listenable _moves = Listenable.merge([_travel, _to]);

  List<GlobalKey> _keys() => [for (final _ in widget.items) GlobalKey()];

  @override
  void didUpdateWidget(FilterChipRow old) {
    super.didUpdateWidget(old);
    if (old.items.length != widget.items.length) _chips = _keys();
  }

  @override
  void dispose() {
    _travel.dispose();
    _to.dispose();
    super.dispose();
  }

  /// After layout: send the pill to the chosen chip, or put it there at
  /// once when it first appears or motion is reduced.
  void _follow() {
    if (!mounted) return;
    final chosen = widget.items.indexWhere((item) => item.selected);
    final row = _row.currentContext?.findRenderObject() as RenderBox?;
    final chip = chosen < 0
        ? null
        : _chips[chosen].currentContext?.findRenderObject() as RenderBox?;
    final target = row == null || chip == null
        ? null
        : chip.localToGlobal(Offset.zero, ancestor: row) & chip.size;
    final current = _to.value;
    if (target == current) return;
    if (target == null ||
        current == null ||
        MediaQuery.disableAnimationsOf(context)) {
      _from = target;
      _travel.value = 1;
      _to.value = target;
      return;
    }
    _from = Rect.lerp(_from, current, _travel.value);
    _to.value = target;
    _travel
      ..value = 0
      ..animateTo(1);
  }

  Rect? _pillAt(Size _) {
    final from = _from;
    final to = _to.value;
    return from == null || to == null
        ? null
        : Rect.lerp(from, to, _travel.value);
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _follow());
    final label = AppTypography.labelMedium;
    final grows =
        MediaQuery.textScalerOf(context).lineHeightOf(label) -
        label.fontSize! * label.height!;
    final height = (AppSize.chip + (grows > 0 ? grows : 0)).ceilToDouble();

    return SizedBox(
      height: height,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.gutter),
        child: Stack(
          key: _row,
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: TravellingPill(
                  moves: _moves,
                  at: _pillAt,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (index, item) in widget.items.indexed) ...[
                  if (index > 0) const SizedBox(width: AppSpace.near),
                  KeyedSubtree(
                    key: _chips[index],
                    child: _Chip(item: item),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// One chip, the theme's: clear while chosen so the travelling pill shows
/// through, white with the hairline otherwise.
class _Chip extends StatelessWidget {
  const _Chip({required this.item});

  final FilterChipItem item;

  /// A round photo inside the chip's height, the chip's edge around it.
  static const _avatar = AppSize.chip - 2 * AppSpace.x1;

  @override
  Widget build(BuildContext context) {
    final avatar = item.avatar;
    final remove = item.onRemove;
    final label = Text(item.label);
    return Pressable(
      child: remove == null
          ? ChoiceChip(
              label: label,
              selected: item.selected,
              selectedColor: Colors.transparent,
              onSelected: (_) => item.onTap(),
              avatar: avatar == null ? null : ClipOval(child: avatar),
              avatarBoxConstraints: const BoxConstraints.tightFor(
                width: _avatar,
                height: _avatar,
              ),
              padding: avatar == null
                  ? null
                  : const EdgeInsetsDirectional.fromSTEB(
                      AppSpace.x1,
                      AppSpace.x1,
                      AppSpace.x3,
                      AppSpace.x1,
                    ),
            )
          : InputChip(
              label: label,
              selected: true,
              selectedColor: Colors.transparent,
              onPressed: item.onTap,
              onDeleted: remove,
              deleteIcon: Icon(
                AppIcons.close,
                size: AppSize.glyphSm,
                color: Theme.of(context).colorScheme.onPrimary,
              ),
              deleteButtonTooltipMessage: "Clear ${item.label}",
            ),
    );
  }
}
