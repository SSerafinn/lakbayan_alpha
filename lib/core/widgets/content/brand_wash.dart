import "package:flutter/material.dart";

/// The colour that rises from the bottom of a screen and clears before it
/// reaches the content above.
///
/// It exists because a full-screen tint fights `footer.webp`: the artwork is
/// vivid and flat, and wrapping it in a pastel sheet makes both look weaker.
/// Confined to the foot of the screen it reads as light coming off the water,
/// and it is what carries a page's colour from the landing pages through to
/// sign-in.
///
/// Three stops rather than two. A straight two-stop ramp puts its midpoint
/// halfway up, which leaves a visible edge where the colour "starts"; holding
/// most of the fade in the lower half instead lets it disappear into the page.
class BrandWash extends StatelessWidget {
  const BrandWash({required this.color, super.key});

  final Color color;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          color.withValues(alpha: 0),
          color.withValues(alpha: 0.35),
          color,
        ],
        stops: const [0, 0.62, 1],
      ),
    ),
  );
}
