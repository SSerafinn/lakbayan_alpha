import "package:flutter_test/flutter_test.dart";
import "package:lakbayan/features/guides/domain/guide_providers.dart";

/// `contact` is free text (`docs/DATA_MODEL.md`), typed by whoever filled in
/// the intake sheet. These are the shapes it actually arrives in.
void main() {
  group("a phone number", () {
    test("dials a mobile as written", () {
      expect(contactUri("0917 123 4567"), Uri.parse("tel:09171234567"));
    });

    test("keeps the country code", () {
      expect(contactUri("+63 917 123 4567"), Uri.parse("tel:+639171234567"));
    });

    test("reads through brackets, dots and dashes", () {
      expect(contactUri("(078) 844-1234"), Uri.parse("tel:0788441234"));
      expect(contactUri("0917.123.4567"), Uri.parse("tel:09171234567"));
    });

    test("finds a number inside a sentence", () {
      expect(
        contactUri("Text or call 0917 123 4567 after 5pm"),
        Uri.parse("tel:09171234567"),
      );
    });
  });

  group("two phone numbers", () {
    // The regression: stripping the whole field to its digits joined the two
    // into one number nobody owns.
    test("dials the first, split by a slash", () {
      expect(
        contactUri("0917 123 4567 / 0918 765 4321"),
        Uri.parse("tel:09171234567"),
      );
    });

    test("dials the first, split by a word", () {
      expect(
        contactUri("+63 917 123 4567 or +63 918 765 4321"),
        Uri.parse("tel:+639171234567"),
      );
    });

    test("dials the first, one per line", () {
      // How a CMS text field most often separates them.
      expect(
        contactUri("0917 123 4567\n0918 765 4321"),
        Uri.parse("tel:09171234567"),
      );
    });

    test("dials the first, split by a comma", () {
      expect(
        contactUri("0917 123 4567, 0918 765 4321"),
        Uri.parse("tel:09171234567"),
      );
    });

    test("gives up rather than invent one when only a space divides them", () {
      // Twenty-two digits in one run: there is no telling where one number
      // ends. No link, and the text on the card, beats a call to nobody.
      expect(contactUri("0917 123 4567 0918 765 4321"), isNull);
    });
  });

  group("an email", () {
    test("opens mail", () {
      expect(
        contactUri("juan@example.com"),
        Uri(scheme: "mailto", path: "juan@example.com"),
      );
    });

    test("wins over a phone number in the same field", () {
      // Existing behaviour, pinned so a change to it is a decision rather
      // than an accident.
      expect(
        contactUri("0917 123 4567 / juan@example.com"),
        Uri(scheme: "mailto", path: "juan@example.com"),
      );
    });
  });

  group("nothing to reach", () {
    test("too few digits to be a number", () {
      expect(contactUri("Room 12, Purok 3"), isNull);
    });

    test("an empty field", () {
      expect(contactUri(""), isNull);
    });

    test("words only", () {
      expect(contactUri("Ask at the municipal tourism office"), isNull);
    });
  });
}
