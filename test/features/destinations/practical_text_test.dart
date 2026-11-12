import "package:flutter_test/flutter_test.dart";
import "package:lakbayan/core/models/destination.dart";
import "package:lakbayan/features/destinations/domain/practical_text.dart";

import "../../support/fake_destination_repository.dart";

// The CMS card preview ports these rules (cms/src/types/preview.ts) and
// mirrors these cases in preview.test.ts: change both together.

String? _price(String? fee) => entryPrice(
  testDestination(id: "callao")
      .copyWith(practical: PracticalInfo(entryFee: fee)),
);

void main() {
  group("tidyFact", () {
    test("writes times as 8 AM and a leading PHP as ₱", () {
      expect(tidyFact("8:00am – 4:00pm"), (
        value: "8:00 AM – 4:00 PM",
        note: null,
      ));
      expect(tidyFact("php 20"), (value: "₱20", note: null));
    });

    test("puts what follows the first comma on its own line", () {
      expect(tidyFact("PHP 50, children free"), (
        value: "₱50",
        note: "Children free",
      ));
    });

    test("keeps a thousands separator in the number", () {
      expect(tidyFact("PHP 1,000"), (value: "₱1,000", note: null));
      expect(tidyFact("PHP 1,500 per boat"), (
        value: "₱1,500 per boat",
        note: null,
      ));
      expect(tidyFact("PHP 1,500, children free"), (
        value: "₱1,500",
        note: "Children free",
      ));
      expect(tidyFact("PHP 1,000,000"), (value: "₱1,000,000", note: null));
    });

    test("still breaks at a comma that is not grouping thousands", () {
      expect(tidyFact("PHP 50,children free"), (
        value: "₱50",
        note: "Children free",
      ));
      expect(tidyFact("PHP 50, 100 with a guide"), (
        value: "₱50",
        note: "100 with a guide",
      ));
    });

    test("moves a closing daily to the second line", () {
      expect(tidyFact("8am to 5pm daily"), (
        value: "8 AM to 5 PM",
        note: "Daily",
      ));
    });

    test("is nothing for an empty field", () {
      expect(tidyFact("   "), isNull);
      expect(tidyFact(null), isNull);
    });
  });

  group("entryPrice", () {
    test("is Free, or short words with a number", () {
      expect(_price("Free"), "Free");
      expect(_price("free"), "Free");
      expect(_price("PHP 20"), "₱20");
      expect(_price("PHP 50, children free"), "₱50");
    });

    test("keeps the thousands of a fee whole", () {
      expect(_price("PHP 1,000"), "₱1,000");
      expect(_price("PHP 1,500, children free"), "₱1,500");
    });

    test("is nothing when the fee is too long for a photo", () {
      // "₱1,500 per boat" is 15 characters; once it was cut to "₱1".
      expect(_price("PHP 1,500 per boat"), isNull);
      expect(_price("₱50 for adults and ₱20 for children"), isNull);
    });

    test("is nothing for words that are not a price", () {
      expect(_price("Boat hire"), isNull);
      expect(_price(""), isNull);
      expect(_price(null), isNull);
    });
  });
}
