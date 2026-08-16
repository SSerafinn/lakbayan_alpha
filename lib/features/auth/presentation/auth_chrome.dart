import "package:flutter/material.dart";

import "../../../core/theme/app_dimens.dart";
import "../../../core/theme/app_typography.dart";
import "../../../core/theme/lakbayan_colors.dart";
import "../../../core/widgets/brand_wash.dart";

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
          BrandWash(color: context.lakbayan.goldContainer),
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
  final VoidCallback onDismiss;

  @override
  State<AuthSheet> createState() => _AuthSheetState();
}

class _AuthSheetState extends State<AuthSheet> {
  static const double _maxNudge = 40;

  double _nudge = 0;

  @override
  Widget build(BuildContext context) {
    return AnimatedSlide(
      offset: Offset(0, _nudge / MediaQuery.sizeOf(context).height),
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppRadius.sheet),
          ),
          boxShadow: AppShadow.raised,
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
                    if (_nudge > 0 || (details.primaryVelocity ?? 0) > 0) {
                      widget.onDismiss();
                      return;
                    }
                    setState(() => _nudge = 0);
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
              color: context.lakbayan.line,
              borderRadius: AppRadius.pillAll,
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
