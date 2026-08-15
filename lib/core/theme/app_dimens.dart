import "package:flutter/material.dart";

import "app_colors.dart";

/// Spacing scale (`space.*` in tokens.json). 4dp base grid.
abstract final class AppSpace {
  static const x1 = 4.0;
  static const x2 = 8.0;
  static const x3 = 12.0;
  static const x4 = 16.0;
  static const x5 = 20.0;
  static const x6 = 24.0;
  static const x8 = 32.0;
}

/// Corner radii (`radius.*`). The design system's rule is 12–16dp everywhere,
/// with the pill reserved for chips since the 2026-08 rebrand.
abstract final class AppRadius {
  static const sm = 8.0;
  static const md = 12.0; // cards, inputs, large chips
  static const lg = 16.0; // cards, sheets, buttons
  static const pill = 999.0; // chips only, since the 2026-08 rebrand

  /// A sheet drawn up over content behind it. Larger than [lg] so the corners
  /// read as a separate surface rather than a rounded box.
  static const sheet = 28.0;

  static const smAll = BorderRadius.all(Radius.circular(sm));
  static const mdAll = BorderRadius.all(Radius.circular(md));
  static const lgAll = BorderRadius.all(Radius.circular(lg));
  static const pillAll = BorderRadius.all(Radius.circular(pill));
}

/// Fixed sizes (`size.*`).
///
/// The first three come from the design system. The rest were added for the
/// landing and auth screens: they are layout sizes those screens share, kept
/// here rather than inline so the two stay in step with each other.
abstract final class AppSize {
  /// Android accessibility minimum. Every tappable target must meet this.
  static const minTouchTarget = 48.0;
  static const appBarHeight = 56.0;
  static const bottomNav = 64.0;

  /// Primary form buttons. At the touch-target minimum: a full-width action
  /// does not need extra height to be found.
  static const formButton = 48.0;

  /// A large standalone icon, such as the landing page's swipe affordance.
  /// Inline icons stay at Material's default and do not need a token.
  static const iconLarge = 40.0;

  /// The colour wash behind the shoreline. Taller than the band itself so the
  /// colour has room to clear before it reaches the copy above.
  static const wash = 340.0;

  /// The splash progress bar. Deliberately narrow: it marks time passing, it
  /// does not report progress.
  static const progressBar = 120.0;

  /// The grab bar at the top of the auth sheet.
  static const dragHandleWidth = 36.0;
  static const dragHandleHeight = 4.0;

  /// How far the auth sheet rides up over the illustrated header. Generous, so
  /// the form has room without the artwork being cropped further.
  static const authCardOverlap = 116.0;

  /// Two lines of [AppTypography.brandDisplay], with headroom for the tall
  /// caps of a display face. Reserved so copy does not shift while a heading
  /// animates in.
  static const brandDisplayBlock = 124.0;

  /// Three lines of [AppTypography.bodyLarge], the longest the landing copy
  /// runs. A floor rather than a fixed height: the pages are centred, so
  /// without it a page whose body wraps shorter sits lower than the rest.
  static const landingBodyBlock = 72.0;
}

/// The shoreline band, `footer.webp`, which is 1440 x 319.
///
/// Laid out three screen-widths wide so a page turn moves it exactly one
/// screen and the pan tracks the finger 1:1 on any device. The height follows
/// from that, so both screens derive it the same way.
const double shorelineAspectRatio = 1440 / 319;
const int shorelinePages = 3;

double shorelineBand(BuildContext context) =>
    MediaQuery.sizeOf(context).width * shorelinePages / shorelineAspectRatio;

/// Shadows (`elevation.*`). Expressed as explicit [BoxShadow] lists rather than
/// Material elevation numbers — the design system specifies exact colours and
/// offsets, and Material's elevation overlay would tint them.
abstract final class AppShadow {
  static const card = <BoxShadow>[
    BoxShadow(color: Color(0x141E2733), blurRadius: 3, offset: Offset(0, 1)),
    BoxShadow(color: Color(0x0A1E2733), blurRadius: 2, offset: Offset(0, 1)),
  ];

  static const raised = <BoxShadow>[
    BoxShadow(color: Color(0x1A123D24), blurRadius: 14, offset: Offset(0, 4)),
  ];

  static const nav = <BoxShadow>[
    BoxShadow(color: Color(0x0F1E2733), blurRadius: 8, offset: Offset(0, -1)),
  ];
}

/// A hairline border in the design system's divider colour.
BoxBorder get appHairline => Border.all(color: AppColors.line);
