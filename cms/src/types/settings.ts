import type { Timestamp } from "firebase/firestore";
import { slugify, type Destination } from "./destination";

/**
 * `settings/{taxonomy | app | policies}` — mirrors `docs/DATA_MODEL.md` and
 * `lib/core/models/app_settings.dart`. Three fixed documents; the rules allow
 * no others.
 */
export const SETTINGS_SCHEMA_VERSION = 1;

export type SettingsId = "taxonomy" | "app" | "policies";

/** Written on every settings document beside its own fields. */
export type Stamped = {
  updatedAt?: Timestamp;
  updatedBy?: string | null;
  schemaVersion?: number;
};

export type TaxonomySettings = { towns: string[] };

export type OfficeContact = {
  office?: string;
  phone?: string;
  email?: string;
  hours?: string;
  address?: string;
};

export type Hotline = { label: string; number: string };

export type Announcement = {
  text: string;
  /** Past this, the notice is over. Null runs until removed. */
  until?: Timestamp | null;
};

export type AppSettings = {
  contact: OfficeContact;
  hotlines: Hotline[];
  announcement: Announcement | null;
};

export type PolicySettings = {
  privacy: string;
  terms: string;
  privacyUpdatedAt?: Timestamp | null;
  termsUpdatedAt?: Timestamp | null;
};

export function emptyApp(): AppSettings {
  return { contact: {}, hotlines: [], announcement: null };
}

export function emptyPolicies(): PolicySettings {
  return { privacy: "", terms: "" };
}

/** A notice is limited to what fits on one banner line on a phone. */
export const MAX_ANNOUNCEMENT = 160;

// ---- towns --------------------------------------------------------------------

/**
 * Tidy a town list: trimmed, no blanks, no near-duplicates, sorted.
 *
 * "Near" is the slug: "Peñablanca" and "Penablanca" are one town written two
 * ways, and keeping both is exactly how a town becomes two offline bundles.
 * The first spelling in the list wins, so an admin's correction stays put.
 */
export function normalizeTowns(towns: string[]): string[] {
  const seen = new Set<string>();
  const out: string[] = [];
  for (const raw of towns) {
    const t = raw.trim();
    const key = slugify(t);
    if (!t || seen.has(key)) continue;
    seen.add(key);
    out.push(t);
  }
  return out.sort((a, b) => a.localeCompare(b));
}

/**
 * Towns that destinations use but the list does not have — usually a
 * misspelling, and worth fixing before it splits a town's offline bundle.
 */
export function townsNotListed(
  destinations: Pick<Destination, "town">[],
  towns: string[],
): { town: string; count: number }[] {
  const listed = new Set(towns);
  const counts = new Map<string, number>();
  for (const d of destinations) {
    const t = d.town.trim();
    if (!t || listed.has(t)) continue;
    counts.set(t, (counts.get(t) ?? 0) + 1);
  }
  return [...counts.entries()]
    .map(([town, count]) => ({ town, count }))
    .sort((a, b) => a.town.localeCompare(b.town));
}

// ---- tags ---------------------------------------------------------------------

/** Every tag in use, most used first. */
export function tagUsage(
  destinations: Pick<Destination, "tags">[],
): { tag: string; count: number }[] {
  const counts = new Map<string, number>();
  for (const d of destinations) {
    for (const t of d.tags ?? []) counts.set(t, (counts.get(t) ?? 0) + 1);
  }
  return [...counts.entries()]
    .map(([tag, count]) => ({ tag, count }))
    .sort((a, b) => b.count - a.count || a.tag.localeCompare(b.tag));
}

/**
 * One destination's tags with `from` renamed to `to`.
 *
 * Renaming onto a tag the place already has merges the two rather than
 * leaving a duplicate. An empty `to` removes the tag. Order is kept.
 */
export function renameTag(tags: string[], from: string, to: string): string[] {
  const target = to.trim().toLowerCase();
  const out: string[] = [];
  for (const t of tags) {
    const next = t === from ? target : t;
    if (next && !out.includes(next)) out.push(next);
  }
  return out;
}

// ---- announcement -------------------------------------------------------------

export type AnnouncementState = "off" | "live" | "ended";

/** Whether the app would show the notice now — the same test as the Dart model's. */
export function announcementState(
  a: { text: string; until?: { toMillis(): number } | null } | null,
  now: number,
): AnnouncementState {
  if (!a || !a.text.trim()) return "off";
  if (a.until && a.until.toMillis() <= now) return "ended";
  return "live";
}

/**
 * The day an admin picks, as the moment the notice ends.
 *
 * "Show until 20 Oct" means through the 20th, so the notice ends at the start
 * of the 21st, local time. Storing the 20th itself would end it a day early.
 */
export function untilFromDateInput(value: string): Date | null {
  const m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(value);
  if (!m) return null;
  return new Date(Number(m[1]), Number(m[2]) - 1, Number(m[3]) + 1);
}

/** The inverse, for showing a stored end back in a date field. */
export function dateInputFromUntil(until: Date | null | undefined): string {
  if (!until) return "";
  const last = new Date(until.getTime() - 1); // the final moment it is shown
  const pad = (n: number) => String(n).padStart(2, "0");
  return `${last.getFullYear()}-${pad(last.getMonth() + 1)}-${pad(last.getDate())}`;
}

// ---- hotlines -----------------------------------------------------------------

/**
 * What is wrong with the hotline list, or null. A line with a label and no
 * number is the dangerous half-entry: someone in trouble finds the name and
 * nothing to call.
 */
export function hotlineProblem(hotlines: Hotline[]): string | null {
  const half = hotlines.find(
    (h) => Boolean(h.label.trim()) !== Boolean(h.number.trim()),
  );
  if (!half) return null;
  return half.label.trim()
    ? `"${half.label.trim()}" has no number.`
    : `A number (${half.number.trim()}) has no label.`;
}

/** Drop rows left entirely blank, and trim the rest. */
export function cleanHotlines(hotlines: Hotline[]): Hotline[] {
  return hotlines
    .map((h) => ({ label: h.label.trim(), number: h.number.trim() }))
    .filter((h) => h.label || h.number);
}
