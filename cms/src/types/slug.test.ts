import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";

import { slugify } from "./destination";

/**
 * The TypeScript half of the slug contract.
 *
 * The JavaScript half is `scripts/lib/slug.test.mjs`, and it asserts this same
 * fixture. Two implementations exist only because the CMS is TypeScript and the
 * importer is a plain Node script — the language boundary is real, the
 * behaviour must not be.
 *
 * What goes wrong if they drift: `import-content.mjs` re-derives a slug to
 * decide whether a spreadsheet row is a destination the CMS already created. A
 * single character of disagreement and it stops recognising them, so a
 * re-import creates a second copy of every place in the province rather than
 * updating the originals.
 */
const here = dirname(fileURLToPath(import.meta.url));
const fixture = JSON.parse(
  readFileSync(join(here, "../../../scripts/lib/slug-cases.json"), "utf8"),
) as { cases: { name?: string; slug?: string }[] };

const cases = fixture.cases.filter(
  (c): c is { name: string; slug: string } => c.name !== undefined,
);

describe("slugify", () => {
  it("has cases to check", () => {
    // Guards against a moved or renamed fixture quietly reducing this file to
    // an empty suite that passes.
    expect(cases.length).toBeGreaterThan(10);
  });

  it.each(cases)("$name -> $slug", ({ name, slug }) => {
    expect(slugify(name)).toBe(slug);
  });

  it("never exceeds 60 characters", () => {
    for (const { name } of cases) expect(slugify(name).length).toBeLessThanOrEqual(60);
  });

  it("never starts or ends with a separator", () => {
    for (const { name } of cases) {
      expect(slugify(name)).not.toMatch(/^-|-$/);
    }
  });
});
