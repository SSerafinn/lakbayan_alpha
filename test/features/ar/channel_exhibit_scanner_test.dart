import "package:flutter/services.dart";
import "package:flutter_test/flutter_test.dart";
import "package:lakbayan/features/ar/data/channel_exhibit_scanner.dart";
import "package:lakbayan/features/ar/domain/exhibit_scanner.dart";

/// The Dart half of the channel to `ExhibitScanActivity`. The Kotlin half
/// answers with these same strings; a change to one is a change to both.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const scanner = ChannelExhibitScanner();
  final calls = <MethodCall>[];

  void answer(Object? Function(MethodCall call) reply) =>
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(ChannelExhibitScanner.channel, (
            call,
          ) async {
            calls.add(call);
            return reply(call);
          });

  setUp(calls.clear);
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(ChannelExhibitScanner.channel, null),
  );

  group("support", () {
    for (final (reply, expected) in [
      ("supported", ArSupport.available),
      // The scan screen offers the install itself.
      ("installable", ArSupport.available),
      ("unknown", ArSupport.available),
      ("unsupported", ArSupport.unsupported),
    ]) {
      test("reads '$reply' as $expected", () async {
        answer((_) => reply);
        expect(await scanner.support(), expected);
      });
    }

    test("is unsupported where there is no native side", () async {
      // No handler: the web, iOS, and a build without the activity.
      expect(await scanner.support(), ArSupport.unsupported);
    });

    test("is unsupported when the native side fails", () async {
      answer((_) => throw PlatformException(code: "boom"));
      expect(await scanner.support(), ArSupport.unsupported);
    });
  });

  group("scan", () {
    const marker = ScanMarker(
      exhibitId: "e1",
      filePath: "/cache/ar-markers/e1.webp",
      widthM: 0.3,
      title: "The bell",
      description: "Cast in Manila.",
    );

    const colors = ScanColors(
      primary: Color(0xFF1B6B3A),
      onPrimary: Color(0xFFFFFFFF),
      surface: Color(0xFFFFFFFF),
      onSurface: Color(0xFF1A1C1A),
      onSurfaceVariant: Color(0xFF5B615B),
    );

    Future<ScanOutcome> scan() => scanner.scan(
      placeName: "Cagayan Museum",
      markers: const [marker],
      colors: colors,
    );

    test("hands over the place and every marker", () async {
      answer((_) => {"result": "cancelled"});
      await scan();

      expect(calls.single.method, "scan");
      expect(calls.single.arguments, {
        "placeName": "Cagayan Museum",
        "markers": [
          {
            "id": "e1",
            "path": "/cache/ar-markers/e1.webp",
            "widthM": 0.3,
            "title": "The bell",
            "description": "Cast in Manila.",
          },
        ],
        "colors": {
          "primary": 0xFF1B6B3A,
          "onPrimary": 0xFFFFFFFF,
          "surface": 0xFFFFFFFF,
          "onSurface": 0xFF1A1C1A,
          "onSurfaceVariant": 0xFF5B615B,
        },
      });
    });

    test("reads each answer", () async {
      answer((_) => {"result": "found", "id": "e1"});
      expect(
        await scan(),
        isA<ExhibitRecognised>().having((o) => o.exhibitId, "id", "e1"),
      );

      answer((_) => {"result": "cameraDenied"});
      expect(
        await scan(),
        isA<ScanUnavailable>().having(
          (o) => o.problem,
          "problem",
          ScanProblem.cameraDenied,
        ),
      );

      answer((_) => {"result": "unavailable"});
      expect(
        await scan(),
        isA<ScanUnavailable>().having(
          (o) => o.problem,
          "problem",
          ScanProblem.arUnavailable,
        ),
      );

      answer((_) => {"result": "cancelled"});
      expect(await scan(), isA<ScanClosed>());
    });

    test("a scan that cannot start reads as unavailable", () async {
      expect(
        await scan(),
        isA<ScanUnavailable>().having(
          (o) => o.problem,
          "problem",
          ScanProblem.arUnavailable,
        ),
      );
    });
  });
}
