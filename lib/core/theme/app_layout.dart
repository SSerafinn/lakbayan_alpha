import "package:flutter/widgets.dart";

/// Window size classes (design doc 07). One anatomy per screen, three
/// resolutions; a screen decides its form here and nowhere else.
///
/// No widget contains a raw width number. All width decisions go through
/// [WidthClass] so the breakpoints can move in one place.
enum WidthClass {
  /// Phones. One pane, bottom navigation, depth by pushing forward.
  compact,

  /// Small tablets, foldables, split screen. A rail and a second pane become
  /// possible. This is the class that reveals whether the anatomy was designed
  /// or stretched.
  medium,

  /// Tablets and desktop windows. A persistent panel and multiple panes.
  expanded,
}

/// Material 3 breakpoints: 600 and 840 logical pixels.
WidthClass widthClassOf(double width) {
  if (width < 600) return WidthClass.compact;
  if (width < 840) return WidthClass.medium;
  return WidthClass.expanded;
}

extension WidthClassX on BuildContext {
  /// Reads `MediaQuery.sizeOf` rather than `of`, so the widget rebuilds only
  /// when the size changes, not on every inset or scale change.
  WidthClass get widthClass => widthClassOf(MediaQuery.sizeOf(this).width);
}
