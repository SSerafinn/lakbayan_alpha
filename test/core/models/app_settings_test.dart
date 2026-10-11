import "package:cloud_firestore/cloud_firestore.dart";
import "package:flutter_test/flutter_test.dart";
import "package:lakbayan/core/models/app_settings.dart";

/// The `settings` documents as the CMS writes them. These pin the contract in
/// docs/DATA_MODEL.md from the app's side: field names, what may be missing,
/// and how a notice decides it is over.
void main() {
  group("AppSettings.fromJson", () {
    test("reads a full document as the CMS writes it", () {
      final s = AppSettings.fromJson({
        "contact": {"office": "Provincial Tourism Office", "phone": "0900"},
        "hotlines": [
          {"label": "Emergency", "number": "911"},
          {"label": "MDRRMO", "number": "0900 000 0000"},
        ],
        "announcement": {
          "text": "Callao Cave closed Monday.",
          "until": Timestamp.fromDate(DateTime.utc(2026, 10, 20)),
        },
        // Written on every document, not part of the model.
        "schemaVersion": 1,
        "updatedAt": Timestamp.fromDate(DateTime.utc(2026, 10, 12)),
        "updatedBy": "uid",
      });

      expect(s.contact?.office, "Provincial Tourism Office");
      expect(s.hotlines.map((h) => h.label), ["Emergency", "MDRRMO"]);
      // Timestamp.toDate() is local time; the instant is what must match.
      expect(
        s.announcement!.until!.isAtSameMomentAs(DateTime.utc(2026, 10, 20)),
        isTrue,
      );
    });

    test("tolerates an empty document", () {
      // A fresh project has no settings until someone saves them.
      final s = AppSettings.fromJson({});
      expect(s.contact, isNull);
      expect(s.hotlines, isEmpty);
      expect(s.announcement, isNull);
    });
  });

  group("Announcement.isLiveAt", () {
    final now = DateTime.utc(2026, 10, 12, 9);

    test("runs until removed when it has no end", () {
      expect(const Announcement(text: "Open late").isLiveAt(now), isTrue);
    });

    test("ends at its date", () {
      final a = Announcement(text: "Closed", until: DateTime.utc(2026, 10, 12));
      expect(a.isLiveAt(now), isFalse);
      expect(a.isLiveAt(DateTime.utc(2026, 10, 11)), isTrue);
    });

    test("never shows an empty notice", () {
      expect(const Announcement(text: "  ").isLiveAt(now), isFalse);
    });
  });

  test("policies default to empty text with no dates", () {
    final p = PolicySettings.fromJson({"privacy": "We keep little."});
    expect(p.privacy, "We keep little.");
    expect(p.terms, "");
    expect(p.privacyUpdatedAt, isNull);
  });

  test("taxonomy reads the town list", () {
    expect(
      TaxonomySettings.fromJson({
        "towns": ["Peñablanca", "Piat"],
      }).towns,
      ["Peñablanca", "Piat"],
    );
  });
}
