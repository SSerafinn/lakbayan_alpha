import "dart:convert";
import "dart:io";

import "package:flutter_test/flutter_test.dart";
import "package:lakbayan/core/theme/category_glyphs.dart";

/// The icons the CMS offers come from design/category-glyphs.json; the app
/// transcribes them as constants. A name the CMS offers and this build lacks
/// would draw as Other; a codepoint off by one would draw the wrong picture.
void main() {
  final glyphs =
      (jsonDecode(File("design/category-glyphs.json").readAsStringSync())
              as Map<String, dynamic>)["glyphs"]
          as List<dynamic>;

  test("lists every icon the CMS offers, in its order", () {
    expect(CategoryGlyphs.names, [for (final g in glyphs) g["name"]]);
  });

  test(
    "draws each at the codepoint the shared file gives, in both weights",
    () {
      for (final g in glyphs) {
        final code = int.parse(g["codepoint"] as String, radix: 16);
        final name = g["name"] as String;
        expect(CategoryGlyphs.of(name)?.codePoint, code, reason: name);
        expect(
          CategoryGlyphs.of(name, filled: true)?.codePoint,
          code,
          reason: name,
        );
      }
    },
  );

  test("knows nothing it was not given", () {
    expect(CategoryGlyphs.of("no-such-icon"), isNull);
  });
}
