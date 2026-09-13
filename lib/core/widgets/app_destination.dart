import "package:flutter/widgets.dart";

/// One top-level section of the app.
///
/// Declared once and handed to whichever form the navigation region chooses
/// ([AdaptiveNavigation], [FloatingTabBar]). If every form were built from
/// its own list, the anatomy would not have been designed once and they
/// would drift (design doc 08).
class AppDestination {
  const AppDestination({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
}
