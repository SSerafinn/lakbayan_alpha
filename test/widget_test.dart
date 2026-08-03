import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";
import "package:lakbayan/app.dart";

void main() {
  testWidgets("app boots to the placeholder home screen", (tester) async {
    await tester.pumpWidget(const ProviderScope(child: LakbayanApp()));
    await tester.pumpAndSettle();

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.widgetWithText(AppBar, "Lakbayan"), findsOneWidget);
  });
}
