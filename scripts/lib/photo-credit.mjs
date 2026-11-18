// A photo's credit and licence on a destination, `imageCredits` (schema v5).
// See docs/DATA_MODEL.md, "Changes in v5".
//
// Kept out of import-content.mjs so the rule for what a re-import keeps can be
// tested without a workbook or an emulator.

/**
 * Whether a licence asks for its author to be named: any Creative Commons
 * licence but CC0. The CMS holds the same rule (`needsAttribution` in
 * cms/src/types/photo-credit.ts) and will not publish a photo that breaks it.
 */
export function needsAttribution(licence) {
  const l = (licence ?? "").trim();
  return /^(cc|creative commons)\b/i.test(l) && !/\bzero\b/i.test(l);
}

/** `{ credit?, licence? }` from a sheet row's two columns, or null if both are blank. */
export function creditEntry(credit, licence) {
  const entry = {};
  const c = (credit ?? "").trim();
  const l = (licence ?? "").trim();
  if (c) entry.credit = c;
  if (l) entry.licence = l;
  return Object.keys(entry).length ? entry : null;
}

/**
 * The `imageCredits` map to write, or null to leave the field alone.
 *
 * `photos` is the sheet's photos for one destination, each `{ path, credit,
 * licence }` with `path` the Storage path its file is (or would be) uploaded
 * to. The sheet is authoritative for what it mentions, as with `images`:
 *
 * - `uploaded` (this run replaced `images` with these photos): the map is
 *   exactly the sheet's. Every photo the old map credited is gone from
 *   `images` now, CMS uploads included.
 * - not uploaded (no --media): `images` stands, so the sheet's credits are
 *   applied to the photos of it already there and every other entry is kept —
 *   a credit an editor typed in the CMS for their own upload survives. A
 *   photo the sheet names that was never uploaded gets no entry; there is no
 *   photo for it to credit.
 *
 * A row with both columns blank clears its photo's entry rather than
 * keeping the old one: blank in the sheet means "no credit", the same as
 * clearing both boxes in the CMS.
 *
 * Returns null when nothing would change, so an unchanged re-import does not
 * rewrite the field.
 */
export function planCredits({ photos, uploaded, previousImages, existing }) {
  if (!photos.length) return null;
  const before = existing && typeof existing === "object" ? existing : {};

  let next;
  if (uploaded) {
    next = {};
    for (const p of photos) {
      const entry = creditEntry(p.credit, p.licence);
      if (entry) next[p.path] = entry;
    }
  } else {
    next = { ...before };
    for (const p of photos) {
      if (!previousImages.includes(p.path)) continue;
      const entry = creditEntry(p.credit, p.licence);
      if (entry) next[p.path] = entry;
      else delete next[p.path];
    }
  }
  return sameCredits(before, next) ? null : next;
}

function sameCredits(a, b) {
  const flat = (m) =>
    JSON.stringify(
      Object.keys(m)
        .sort()
        .map((k) => [k, m[k]?.credit ?? null, m[k]?.licence ?? null]),
    );
  return flat(a) === flat(b);
}
