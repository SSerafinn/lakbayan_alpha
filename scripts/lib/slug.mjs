/**
 * URL-safe slug from a name.
 *
 * **This must stay identical to `slugify` in `cms/src/types/destination.ts`.**
 * The CMS derives a destination's slug when it is created; `import-content.mjs`
 * re-derives it to decide whether a sheet row is a document that already
 * exists. If the two disagree by so much as one character, the importer stops
 * recognising destinations and silently creates duplicates of the whole
 * province instead of updating it.
 *
 * The language boundary makes one shared implementation impossible, so the
 * contract is pinned by a shared fixture instead: `slug-cases.json` is asserted
 * from both sides — `slug.test.mjs` here, `cms/src/types/slug.test.ts` there.
 * Change the behaviour and both fail until the fixture is updated, which is
 * exactly the intent.
 *
 * Diacritics are stripped rather than dropped, so "Peñablanca" becomes
 * "penablanca" and not "peablanca" — several Cagayan place names carry them.
 */

/**
 * The Unicode combining-marks block, built from a string so the source stays
 * pure ASCII.
 *
 * Written as a regex literal it is a range of *invisible* characters between
 * the brackets, which is how the two former copies of this function came to
 * differ in their source text while behaving the same. Anything that cannot be
 * seen in a diff should not be load-bearing.
 */
const COMBINING_MARKS = new RegExp("[\\u0300-\\u036f]", "g");

export function slugify(name) {
  return name
    .normalize("NFD")
    .replace(COMBINING_MARKS, "")
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "")
    .slice(0, 60);
}
