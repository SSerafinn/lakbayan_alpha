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
/// with pill only for chips and buttons.
abstract final class AppRadius {
  static const sm = 8.0;
  static const md = 12.0; // cards, inputs, large chips
  static const lg = 16.0; // cards, sheets
  static const pill = 999.0;

  static const smAll = BorderRadius.all(Radius.circular(sm));
  static const mdAll = BorderRadius.all(Radius.circular(md));
  static const lgAll = BorderRadius.all(Radius.circular(lg));
  static const pillAll = BorderRadius.all(Radius.circular(pill));
}

/// Fixed sizes (`size.*`).
abstract final class AppSize {
  /// Android accessibility minimum. Every tappable target must meet this.
  static const minTouchTarget = 48.0;
  static const appBarHeight = 56.0;
  static const bottomNav = 64.0;
}

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
