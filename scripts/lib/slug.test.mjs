// The JavaScript half of the slug contract.
//
//   cd scripts && node --test
//
// The TypeScript half lives in cms/src/types/slug.test.ts and asserts the same
// fixture. Both must pass; that is what keeps the CMS's slugs and the
// importer's slugs the same string.

import { strict as assert } from "node:assert";
import { readFileSync } from "node:fs";
import { describe, it } from "node:test";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

import { slugify } from "./slug.mjs";

const here = dirname(fileURLToPath(import.meta.url));
const { cases } = JSON.parse(
  readFileSync(join(here, "slug-cases.json"), "utf8"),
);

describe("slugify", () => {
  for (const { name, slug } of cases) {
    // Comment-only entries in the fixture carry no name.
    if (name === undefined) continue;
    it(`${JSON.stringify(name)} -> ${slug}`, () => {
      assert.equal(slugify(name), slug);
    });
  }

  // Properties that must hold for anything, not just the listed cases. A slug
  // is a deep-link segment, so a stray separator or an over-long value is a
  // broken URL rather than a cosmetic problem.
  it("never exceeds 60 characters", () => {
    for (const { name } of cases) {
      if (name === undefined) continue;
      assert.ok(slugify(name).length <= 60, name);
    }
  });

  it("never starts or ends with a separator", () => {
    for (const { name } of cases) {
      if (name === undefined) continue;
      const slug = slugify(name);
      assert.ok(!slug.startsWith("-") && !slug.endsWith("-"), name);
    }
  });
});
