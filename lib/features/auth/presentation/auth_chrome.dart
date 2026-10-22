import "package:flutter/gestures.dart";
import "package:flutter/material.dart";

import "../../../core/theme/app_dimens.dart";
import "../../../core/theme/app_motion.dart";
import "../../../core/theme/app_typography.dart";
import "../../../core/theme/lakbayan_colors.dart";
import "../../../core/widgets/content/brand_wash.dart";

class AuthHeader extends StatelessWidget {
  const AuthHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      height: shorelineBand(context),
      child: Stack(
        fit: StackFit.expand,
        children: [
          BrandWash(color: context.lakbayan.butter),
          Align(
            alignment: Alignment.bottomCenter,
            child: SizedBox(
              height: shorelineBand(context),
              width: double.infinity,
              child: ClipRect(
                child: OverflowBox(
                  alignment: Alignment.bottomRight,
                  maxWidth: shorelineBand(context) * shorelineAspectRatio,
                  child: Image.asset(
                    "assets/images/footer.webp",
                    width: shorelineBand(context) * shorelineAspectRatio,
                    height: shorelineBand(context),
                    fit: BoxFit.fill,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AuthSheet extends StatefulWidget {
  const AuthSheet({required this.child, required this.onDismiss, super.key});

  final Widget child;

  /// What a downward drag on the handle does.
  ///
  /// Must actually go somewhere. The handle is a visible affordance, so a
  /// caller that wires it to a no-op gets a sheet you can pull at and nothing
  /// else — which is worse than having no handle at all.
  final VoidCallback onDismiss;

  @override
  State<AuthSheet> createState() => _AuthSheetState();
}

class _AuthSheetState extends State<AuthSheet> {
  /// Maximum downward offset (dp) the sheet can be nudged before it snaps
  /// back or dismisses. All dismiss thresholds are derived from this value so
  /// tweaking it here automatically scales every guard below.
  static const double _maxNudge = 40;

  /// Fraction of [_maxNudge] the user must drag past to trigger a positional
  /// dismiss. 0.5 → the sheet must move at least half its allowed travel.
  static const double _nudgeDismissRatio = 0.5;

  /// A downward fling velocity (dp/s) that dismisses without needing a
  /// positional threshold. Expressed as a multiple of Flutter's own
  /// [kMinFlingVelocity] constant so it scales with the platform definition
  /// of "fling".
  static const double _flingDismissScale = 6.0;

  double _nudge = 0;

  bool get _shouldDismissByPosition => _nudge >= _maxNudge * _nudgeDismissRatio;

  bool _shouldDismissByVelocity(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    return velocity >= kMinFlingVelocity * _flingDismissScale;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSlide(
      offset: Offset(0, _nudge / MediaQuery.sizeOf(context).height),
      duration: AppMotion.nudge,
      curve: Curves.easeOut,
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: AppRadii.sheetTop,
        ),
        clipBehavior: Clip.antiAlias,
        child: Material(
          type: MaterialType.transparency,
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onVerticalDragUpdate: (details) => setState(
                    () => _nudge = (_nudge + details.delta.dy).clamp(
                      0.0,
                      _maxNudge,
                    ),
                  ),
                  onVerticalDragEnd: (details) {
                    final dismiss =
                        _shouldDismissByPosition ||
                        _shouldDismissByVelocity(details);
                    // Snap back **unconditionally**, before leaving. The sheet
                    // goes away with the route, so this is normally invisible;
                    // it matters when the route does not change, where
                    // returning early left the sheet translated down by up to
                    // [_maxNudge] for good. It is sized by an [Expanded]
                    // rather than by its content, so that pushed the foot of
                    // the form past the screen edge with no scroll extent to
                    // bring it back.
                    setState(() => _nudge = 0);
                    if (dismiss) widget.onDismiss();
                  },
                  child: const _DragHandle(),
                ),
                Expanded(child: widget.child),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DragHandle extends StatelessWidget {
  const _DragHandle();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpace.x3),
        child: Center(
          child: Container(
            width: AppSize.dragHandleWidth,
            height: AppSize.dragHandleHeight,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.outlineVariant,
              borderRadius: capsuleRadius,
            ),
          ),
        ),
      ),
    );
  }
}

class AuthWordmark extends StatelessWidget {
  const AuthWordmark({super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      "LAKBAYAN",
      textAlign: TextAlign.center,
      style: AppTypography.brandWordmark.copyWith(
        color: Theme.of(context).colorScheme.onSurface,
      ),
    );
  }
}
