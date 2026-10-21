import "package:flutter_test/flutter_test.dart";
import "package:lakbayan/core/models/exhibit.dart";

void main() {
  test("reads an exhibit as the CMS writes it", () {
    final exhibit = Exhibit.fromJson({
      "id": "e1",
      "title": "The bell",
      "order": 1,
      "markerPath": "ar/museum/markers/e1.webp",
      // Firestore hands back a whole number as an int; the width is a double.
      "markerWidthM": 1,
      "ttsText": "Cast in Manila.",
    });

    expect(exhibit.markerWidthM, 1.0);
    expect(exhibit.isScannable, isTrue);
    expect(exhibit.hasNarration, isTrue);
  });

  test("cannot be scanned without a marker of a known size", () {
    const base = Exhibit(
      id: "e1",
      title: "The bell",
      order: 1,
      markerPath: "ar/museum/markers/e1.webp",
      markerWidthM: 0.3,
    );

    expect(base.isScannable, isTrue);
    expect(base.copyWith(markerWidthM: 0).isScannable, isFalse);
    expect(base.copyWith(markerPath: "").isScannable, isFalse);
    expect(base.hasNarration, isFalse);
  });
}
