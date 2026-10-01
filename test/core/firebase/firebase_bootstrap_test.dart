import "package:flutter_test/flutter_test.dart";
import "package:lakbayan/core/firebase/demo_firebase_options.dart";
import "package:lakbayan/core/firebase/firebase_bootstrap.dart";
import "package:lakbayan/firebase_options.dart";

/// What emulator mode reports. The rest of the bootstrap needs a real
/// Firebase to run; this is the part that decides what the developer is told.
void main() {
  const demo = "demo-lakbayan";

  group("emulatorStatusFor", () {
    test("the right project and an answer is the healthy case", () {
      expect(
        emulatorStatusFor(wanted: demo, actual: demo, answered: true),
        FirebaseBootstrapStatus.emulators,
      );
    });

    test("the right project and no answer is unreachable", () {
      expect(
        emulatorStatusFor(wanted: demo, actual: demo, answered: false),
        FirebaseBootstrapStatus.emulatorsUnreachable,
      );
    });

    test("another project is reported even though the suite answered", () {
      // The case that hid for weeks. The suite answers a project it has no
      // data for with an empty result, which is an answer — so "did it
      // answer" alone called this healthy.
      expect(
        emulatorStatusFor(
          wanted: demo,
          actual: "project-lakbayan",
          answered: true,
        ),
        FirebaseBootstrapStatus.emulatorsWrongProject,
      );
    });

    test("another project outranks an unreachable suite", () {
      // Starting the suite would not fix it, so it is the one worth saying.
      expect(
        emulatorStatusFor(
          wanted: demo,
          actual: "project-lakbayan",
          answered: false,
        ),
        FirebaseBootstrapStatus.emulatorsWrongProject,
      );
    });
  });

  group("the two option sets", () {
    test(
      "name different projects, which is what makes the check meaningful",
      () {
        // If these were ever the same id, emulator mode would be running on the
        // real project's options and the check above could not tell.
        expect(
          demoFirebaseOptions.projectId,
          isNot(DefaultFirebaseOptions.android.projectId),
        );
      },
    );

    test("the emulator project is a demo- project", () {
      // Firebase refuses to contact a backend for a `demo-` project, which is
      // the guarantee that emulator mode cannot reach production.
      expect(demoFirebaseOptions.projectId, startsWith("demo-"));
    });
  });
}
