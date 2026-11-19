/**
 * A photo's credit and licence, `imageCredits[path]` on a destination
 * (schemaVersion 5, `docs/DATA_MODEL.md`). Both free text.
 *
 * Absent rather than "" when blank: an empty string would be a credit that
 * says nothing, and the app treats the two alike anyway.
 */
export type ImageCredit = {
  /** Who to name: the photographer, or the owner of a province photo. */
  credit?: string;
  /** "CC BY-SA 4.0", or how the photo was cleared ("Province-owned; …"). */
  licence?: string;
};

/** Keyed by the Storage path exactly as it is in `images`. */
export type ImageCredits = Record<string, ImageCredit>;

const PUBLIC_LICENCE = /^(cc0?|creative commons|public[ -]domain)\b/i;

/**
 * Whether a licence is a public one a visitor is shown: Creative Commons or
 * the public domain. Anything else is read as a permission note.
 */
export function isPublicLicence(licence: string): boolean {
  return PUBLIC_LICENCE.test(licence.trim());
}

/**
 * Whether a licence asks for its author to be named: any Creative Commons
 * licence but CC0. Public domain and permission notes do not — though a
 * province photo is still credited to the province as a courtesy.
 *
 * `scripts/lib/photo-credit.mjs` refuses an import on the same rule.
 */
export function needsAttribution(licence: string): boolean {
  const l = licence.trim();
  return /^(cc|creative commons)\b/i.test(l) && !/\bzero\b/i.test(l);
}

/**
 * The line the app shows on the photo — "Photo: Patrickroque01 / CC BY-SA
 * 4.0" — or null for none. A permission note is left off: it records how a
 * photo was cleared, and is not a notice for a visitor.
 *
 * **The app's `photoCreditLine` must produce the same string**
 * (`lib/features/destinations/domain/photo_credit.dart`). Both assert
 * `photo-credit-cases.json` beside this file; otherwise the CMS would preview
 * one credit and the app show another.
 */
export function photoCreditLine(c: ImageCredit | undefined): string | null {
  const who = c?.credit?.trim() ?? "";
  const licence = c?.licence?.trim() ?? "";
  const parts = [who, isPublicLicence(licence) ? licence : ""].filter(Boolean);
  return parts.length === 0 ? null : `Photo: ${parts.join(" / ")}`;
}

/**
 * Change one photo's credit. Blank fields are dropped, and an entry with
 * nothing left goes too, so clearing both boxes leaves no trace on the
 * document. Text is kept as typed, spaces included, so the box does not
 * fight the cursor; [creditsToSave] trims.
 */
export function withCredit(
  credits: ImageCredits | undefined,
  path: string,
  patch: ImageCredit,
): ImageCredits {
  const next = { ...credits };
  const merged = { ...next[path], ...patch };
  const entry: ImageCredit = {};
  if (merged.credit) entry.credit = merged.credit;
  if (merged.licence) entry.licence = merged.licence;
  if (entry.credit === undefined && entry.licence === undefined) {
    delete next[path];
  } else {
    next[path] = entry;
  }
  return next;
}

/**
 * The credits as they should be written: only for photos still in `images`,
 * trimmed, with blank fields and empty entries gone.
 *
 * A photo taken off would otherwise leave its credit behind, keyed by a path
 * nothing points at — harmless to read, since readers only look up paths in
 * `images`, but it is the document saying something untrue.
 */
export function creditsToSave(
  images: string[],
  credits: ImageCredits | undefined,
): ImageCredits {
  const out: ImageCredits = {};
  for (const path of images) {
    const c = credits?.[path];
    const credit = c?.credit?.trim();
    const licence = c?.licence?.trim();
    if (!credit && !licence) continue;
    out[path] = {
      ...(credit ? { credit } : {}),
      ...(licence ? { licence } : {}),
    };
  }
  return out;
}
