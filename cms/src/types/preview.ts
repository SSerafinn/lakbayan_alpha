import type { Destination } from "./destination";

/**
 * What the app says on a place's photo, ported for the editor's preview.
 *
 * These mirror the Dart that draws the app, and must keep doing so or the
 * preview shows a card the app will not:
 *
 * - `tidyFact`, `entryPrice`: `lib/features/destinations/domain/practical_text.dart`
 * - `placeTags`: `lib/features/destinations/presentation/place_photo.dart`
 *
 * When one of those changes, change its twin here in the same PR.
 */

type Draft = Omit<Destination, "id">;

/**
 * A CMS free-text fact tidied for reading (D-19): times as "8 AM", a leading
 * PHP as ₱, the part after the first comma (or a closing "daily") on its own
 * quieter line, each line starting with a capital. Words stay the editor's;
 * nothing is added. Null when the field is empty.
 */
export function tidyFact(
  raw: string | null | undefined,
): { value: string; note: string | null } | null {
  const text = raw?.trim() ?? "";
  if (text === "") return null;
  const tidy = text
    .replace(
      /(\d{1,2})(?::(\d{2}))?\s*(am|pm)\b/gi,
      (_, hour: string, minute: string | undefined, half: string) =>
        `${hour}${minute === undefined ? "" : `:${minute}`} ${half.toUpperCase()}`,
    )
    .replace(/^PHP\s*/i, "₱");
  const cut = tidy.indexOf(",");
  let value = cut < 0 ? tidy : tidy.slice(0, cut).trim();
  let note = cut < 0 ? "" : tidy.slice(cut + 1).trim();
  if (note === "" && /\s+daily$/i.test(value)) {
    value = value.replace(/\s+daily$/i, "");
    note = "Daily";
  }
  return { value: capital(value), note: note === "" ? null : capital(note) };
}

function capital(text: string): string {
  return text === "" ? text : text[0].toUpperCase() + text.slice(1);
}

/** The longest fee that fits a pill on a photo; a sentence stays in Details. */
const PRICE_LENGTH = 12;

/**
 * What it costs to get in, in the editor's own words ("Free", "₱50"), when
 * that is short enough for a photo and reads as a price: "Free", or words
 * with a number in them. Null otherwise ("Boat hire" is how you get there,
 * not what it costs).
 */
export function entryPrice(entryFee: string | null | undefined): string | null {
  const value = tidyFact(entryFee)?.value;
  if (value === undefined || value.length > PRICE_LENGTH) return null;
  if (!/\d/.test(value) && value.toLowerCase() !== "free") return null;
  return value;
}

export type PlaceTag =
  | { kind: "price"; label: string }
  | { kind: "scan" }
  | { kind: "popular" };

/**
 * At most two tags on a photo, in the order a visitor decides by: what it
 * costs, then what only this app can show, then that it is popular. `hide`
 * drops what the section around the photo says already (the featured deck's
 * own tag says popular).
 *
 * `hasAR` is passed in rather than read from the draft: the stored field is
 * derived on save (`museumHasAR`), and the preview should show what the next
 * save will make it, not what the last one did.
 */
export function placeTags(
  d: Draft,
  hasAR: boolean,
  {
    hide = [],
    most = 2,
  }: { hide?: PlaceTag["kind"][]; most?: number } = {},
): PlaceTag[] {
  const price = hide.includes("price") ? null : entryPrice(d.practical?.entryFee);
  const tags: PlaceTag[] = [];
  if (price !== null) tags.push({ kind: "price", label: price });
  if (hasAR && !hide.includes("scan")) tags.push({ kind: "scan" });
  if (d.popular && !hide.includes("popular")) tags.push({ kind: "popular" });
  return tags.slice(0, most);
}
