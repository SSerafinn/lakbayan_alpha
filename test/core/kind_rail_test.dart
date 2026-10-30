import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:lakbayan/core/theme/app_icons.dart";
import "package:lakbayan/core/theme/app_theme.dart";
import "package:lakbayan/core/widgets/controls/kind_rail.dart";

/// The kinds as glyphs over words (D-19): each a button that says whether it
/// is the one chosen, and reports a tap.
void main() {
  testWidgets("each kind is a button that says whether it is chosen", (
    tester,
  ) async {
    final tapped = <String>[];
    KindRailItem item(String label, {bool selected = false}) => KindRailItem(
      label: label,
      glyph: AppIcons.grid,
      selectedGlyph: AppIcons.grid,
      selected: selected,
      onTap: () => tapped.add(label),
    );

    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
          body: KindRail(items: [item("All", selected: true), item("Food")]),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester.getSemantics(find.text("All")),
      matchesSemantics(
        label: "All",
        isButton: true,
        hasSelectedState: true,
        isSelected: true,
        hasTapAction: true,
        isFocusable: true,
        hasFocusAction: true,
      ),
    );
    expect(
      tester.getSemantics(find.text("Food")),
      matchesSemantics(
        label: "Food",
        isButton: true,
        hasSelectedState: true,
        hasTapAction: true,
        isFocusable: true,
        hasFocusAction: true,
      ),
    );

    await tester.tap(find.text("Food"));
    expect(tapped, ["Food"]);
    semantics.dispose();
  });
}
