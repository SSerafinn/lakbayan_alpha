import "package:riverpod_annotation/riverpod_annotation.dart";

part "home_tab.g.dart";

/// The four tabs of wireframe 1a, in order.
enum HomeTab { explore, map, itineraries, profile }

/// Which tab the shell is showing.
///
/// A provider rather than [State] inside the shell, so a screen *within* a tab
/// can send somebody to another one. Explore's "Create your own tour" hero is
/// the reason: it belongs on Explore and its action belongs on Itineraries, and
/// threading a callback down through two widgets to say so would be worse.
@riverpod
class SelectedHomeTab extends _$SelectedHomeTab {
  @override
  HomeTab build() => HomeTab.explore;

  void select(HomeTab tab) => state = tab;
}
