import "dart:async";
import "dart:io";

import "package:firebase_core/firebase_core.dart";
import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:lakbayan/core/errors/error_copy.dart";
import "package:lakbayan/core/theme/app_theme.dart";
import "package:lakbayan/core/widgets/content/quiet_note.dart";

void main() {
  group("isOfflineError", () {
    test("Firestore, Auth and Storage giving up on the network", () {
      for (final code in [
        "unavailable",
        "deadline-exceeded",
        "network-request-failed",
        "retry-limit-exceeded",
      ]) {
        expect(
          isOfflineError(FirebaseException(plugin: "any", code: code)),
          isTrue,
          reason: code,
        );
      }
    });

    test("a socket, an HTTP failure or a timeout", () {
      expect(isOfflineError(const SocketException("no route")), isTrue);
      expect(isOfflineError(const HttpException("reset")), isTrue);
      expect(isOfflineError(TimeoutException("slow")), isTrue);
    });

    test("anything else is not the network's fault", () {
      expect(
        isOfflineError(
          FirebaseException(
            plugin: "cloud_firestore",
            code: "permission-denied",
          ),
        ),
        isFalse,
      );
      expect(isOfflineError(StateError("bug")), isFalse);
      expect(isOfflineError("a string"), isFalse);
    });
  });

  group("errorCopy", () {
    final refused = FirebaseException(
      plugin: "cloud_firestore",
      code: "permission-denied",
      message: "Missing or insufficient permissions for projects/demo-x.",
    );

    test("leads with what failed, then what to do, offline", () {
      expect(
        errorCopy(
          "Couldn't load destinations.",
          FirebaseException(plugin: "cloud_firestore", code: "unavailable"),
        ),
        "Couldn't load destinations. $offlineErrorHint",
      );
    });

    test("the generic hint for any other failure", () {
      expect(
        errorCopy("Couldn't load destinations.", refused),
        "Couldn't load destinations. $genericErrorHint",
      );
    });

    test("a screen can say better what still works offline", () {
      expect(
        errorCopy(
          "Couldn't load the list of towns.",
          const SocketException("no route"),
          offline: "Towns you have already downloaded still work.",
        ),
        "Couldn't load the list of towns. "
        "Towns you have already downloaded still work.",
      );
    });

    test("never shows the exception's own text", () {
      final copy = errorCopy("Couldn't load destinations.", refused);
      expect(copy, isNot(contains("permission")));
      expect(copy, isNot(contains("demo-x")));
      expect(copy, isNot(contains("FirebaseException")));
    });
  });

  group("QuietNote", () {
    Future<void> pump(WidgetTester tester, Widget note) => tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(body: note),
      ),
    );

    testWidgets("offers no action unless asked", (tester) async {
      await pump(tester, const QuietNote("Nothing here yet."));

      expect(find.byType(TextButton), findsNothing);
    });

    testWidgets("Try again is a text button that calls back", (tester) async {
      var retried = 0;
      await pump(
        tester,
        QuietNote("Couldn't load places.", onRetry: () => retried++),
      );

      // The theme's tertiary, never a filled (let alone gold) button: trying
      // again is not the screen's primary action.
      expect(find.widgetWithText(TextButton, "Try again"), findsOneWidget);
      expect(find.byType(FilledButton), findsNothing);

      await tester.tap(find.text("Try again"));
      expect(retried, 1);
    });
  });
}
