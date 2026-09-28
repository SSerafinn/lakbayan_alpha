/**
 * The project's one slug rule, third copy.
 *
 * `scripts/lib/slug.mjs` and `cms/src/types/destination.ts` hold the others.
 * Three implementations is not an accident: the three packages do not share a
 * build, and importing across them would drag Node tooling into the CMS bundle
 * or a browser dependency into a Cloud Function.
 *
 * What keeps them honest is `scripts/lib/slug-cases.json` — every copy is
 * tested against the same fixture, so a change to one that the others do not
 * follow fails a test rather than silently minting a second id for the same
 * town.
 */
export function slugify(name: string): string {
  return name
    .normalize("NFD")
    .replace(/[̀-ͯ]/g, "")
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "")
    .slice(0, 60);
}
