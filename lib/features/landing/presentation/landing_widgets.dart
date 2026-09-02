import "package:animated_text_kit/animated_text_kit.dart";
import "package:flutter/material.dart";

import "../../../core/theme/app_dimens.dart";
import "../../../core/theme/app_typography.dart";
import "../../../core/theme/lakbayan_colors.dart";

class LandingPage {
  const LandingPage({
    required this.wash,
    required this.greeting,
    required this.body,
  });

  final Color wash;

  final String greeting;
  final String body;
}

class LandingPageContent extends StatelessWidget {
  const LandingPageContent({required this.page, super.key});

  final LandingPage page;

  @override
  Widget build(BuildContext context) {
    final colors = context.lakbayan;
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.x6,
        AppSpace.x4,
        AppSpace.x6,
        0,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppSpace.x6),
          SizedBox(
            height: AppSize.brandDisplayBlock,
            // The greeting types itself out and repeats forever, which is the
            // character of the screen — and exactly what someone who has asked
            // the system to reduce motion does not want looping at them. They
            // get the finished words instead; nothing is lost but the effect.
            child: MediaQuery.disableAnimationsOf(context)
                ? Text(
                    page.greeting,
                    style: AppTypography.brandDisplay.copyWith(
                      color: scheme.onSurface,
                    ),
                  )
                : AnimatedTextKit(
                    key: ValueKey(page.greeting),
                    repeatForever: true,
                    pause: const Duration(milliseconds: 2200),
                    animatedTexts: [
                      TyperAnimatedText(
                        page.greeting,
                        textStyle: AppTypography.brandDisplay.copyWith(
                          color: scheme.onSurface,
                        ),
                        speed: const Duration(milliseconds: 65),
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: AppSpace.x5),
          ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: AppSize.landingBodyBlock,
            ),
            child: Text(
              page.body,
              style: AppTypography.bodyLarge.copyWith(
                color: colors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ShorelineImage extends StatelessWidget {
  const ShorelineImage({super.key});

  @override
  Widget build(BuildContext context) {
    final height = shorelineBand(context);
    return Image.asset(
      "assets/images/footer.webp",
      width: height * shorelineAspectRatio,
      height: height,
      fit: BoxFit.fill,
    );
  }
}

class ShorelineBand extends StatelessWidget {
  const ShorelineBand({required this.page, required this.child, super.key});

  final double page;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final height = shorelineBand(context);
    final offset = -page * MediaQuery.sizeOf(context).width;

    return SizedBox(
      height: height,
      width: double.infinity,
      child: ClipRect(
        child: OverflowBox(
          alignment: Alignment.bottomLeft,
          maxWidth: height * shorelineAspectRatio,
          child: Transform.translate(offset: Offset(offset, 0), child: child),
        ),
      ),
    );
  }
}

class SwipeHint extends StatefulWidget {
  const SwipeHint({required this.atEnd, required this.onTap, super.key});

  final bool atEnd;
  final VoidCallback onTap;

  @override
  State<SwipeHint> createState() => SwipeHintState();
}

class SwipeHintState extends State<SwipeHint>
    with SingleTickerProviderStateMixin {
  late final AnimationController _nudge = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 850),
  );

  /// Whether the nudge is running.
  ///
  /// Exposed so the reduced-motion test can assert on the animation itself
  /// rather than on a pixel offset, which would pass for the wrong reason the
  /// moment the nudge distance changed.
  bool get isNudging => _nudge.isAnimating;

  /// Started here rather than in the initialiser because whether it should run
  /// at all depends on `MediaQuery`, which is not available until dependencies
  /// resolve. Left at rest under reduced motion, so the chevron simply sits
  /// still — it is a hint, and it still points the right way without moving.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduce = MediaQuery.disableAnimationsOf(context);
    if (reduce && _nudge.isAnimating) {
      _nudge.stop();
      _nudge.value = 0;
    } else if (!reduce && !_nudge.isAnimating) {
      _nudge.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _nudge.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.lakbayan;

    return Padding(
      padding: const EdgeInsets.only(right: AppSpace.x3, bottom: AppSpace.x1),
      child: Align(
        alignment: Alignment.centerRight,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: AppRadius.pillAll,
          child: SizedBox(
            height: AppSize.minTouchTarget,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedOpacity(
                  opacity: widget.atEnd ? 1 : 0,
                  duration: const Duration(milliseconds: 260),
                  child: Padding(
                    padding: const EdgeInsets.only(right: AppSpace.x2),
                    child: Text(
                      "GET STARTED",
                      style: AppTypography.overline.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ),
                ),
                AnimatedBuilder(
                  animation: _nudge,
                  builder: (context, _) => Transform.translate(
                    offset: Offset(AppSpace.x2 * _nudge.value, 0),
                    child: Icon(
                      Icons.chevron_right_rounded,
                      size: AppSize.iconLarge,
                      color: colors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
