import type { Timestamp } from "firebase/firestore";
import type { OfflineBundle } from "./bundle";
import { readiness, type Destination, type Status } from "./destination";
import type { Guide } from "./guide";
import { shortDate } from "./format";
import type { Tour } from "./tour";

/**
 * What the dashboard derives from the collections it reads. Pure, so the
 * rules about what counts as "needs attention" are tested rather than eyeballed.
 *
 * Nothing here reads Firestore. The page fetches; this module decides.
 */

function ms(t?: Timestamp): number {
  return t?.toMillis() ?? 0;
}

// ---- recent activity -------------------------------------------------------

export type ActivityKind = "destination" | "tour" | "guide";

export type Activity = {
  kind: ActivityKind;
  id: string;
  name: string;
  /** Where clicking the row goes — the item's editor, not just its section. */
  href: string;
  /** Milliseconds since the epoch of the last write. */
  at: number;
  verb: "Added" | "Edited";
  /**
   * uid of the last editor. Destinations always record one; tours and guides
   * have since 2026-10, so older ones show no name.
   */
  by?: string;
  /** Destinations only — tours and guides have no draft state. */
  status?: Status;
};

/**
 * The most recent writes across the three admin-edited collections.
 *
 * Built from `updatedAt`, not from a log, so it has two blind spots worth
 * knowing: a deletion leaves nothing behind to list, and publishing reads as
 * an edit (the status badge beside it says which way it went). An audit
 * collection would close both, at the cost of a schema change and a write on
 * every save — not worth it until someone needs the history rather than the
 * glance.
 *
 * "Added" means the document has not been written since it was created. Both
 * timestamps come from the same `serverTimestamp()` on create, so they are
 * equal exactly, not merely close.
 */
export function recentActivity(
  {
    destinations,
    tours,
    guides,
  }: { destinations: Destination[]; tours: Tour[]; guides: Guide[] },
  limit = 8,
): Activity[] {
  const verb = (created?: Timestamp, updated?: Timestamp) =>
    created && updated && ms(created) === ms(updated) ? "Added" : "Edited";

  const all: Activity[] = [
    ...destinations.map(
      (d): Activity => ({
        kind: "destination",
        id: d.id,
        name: d.name.trim() || "Untitled destination",
        href: `/destinations/${d.id}`,
        at: ms(d.updatedAt),
        verb: verb(d.createdAt, d.updatedAt),
        by: d.updatedBy ?? undefined,
        status: d.status,
      }),
    ),
    ...tours.map(
      (t): Activity => ({
        kind: "tour",
        id: t.id,
        name: t.title,
        href: `/tours?edit=${encodeURIComponent(t.id)}`,
        at: ms(t.updatedAt),
        verb: verb(t.createdAt, t.updatedAt),
        by: t.updatedBy ?? undefined,
      }),
    ),
    ...guides.map(
      (g): Activity => ({
        kind: "guide",
        id: g.id,
        name: g.name,
        href: `/guides?edit=${encodeURIComponent(g.id)}`,
        at: ms(g.updatedAt),
        verb: verb(g.createdAt, g.updatedAt),
        by: g.updatedBy ?? undefined,
      }),
    ),
  ];

  // A pending serverTimestamp reads back as null in the local snapshot. Such a
  // row is the newest thing there is, not the oldest, but it cannot be dated;
  // leaving it out until the next load is better than sorting it to the end.
  return all
    .filter((a) => a.at > 0)
    .sort((a, b) => b.at - a.at)
    .slice(0, limit);
}

// ---- needs attention -------------------------------------------------------

export type AttentionItem = {
  key: string;
  title: string;
  detail: string;
  href: string;
  /** True when the item is a quick win rather than a problem. */
  ready?: boolean;
};

/**
 * Every draft, with what still stands between it and going live.
 *
 * Document-level checks only. The editor's checklist also inspects the audio
 * guide, which lives in a subcollection — reading every draft's segments to
 * fill a dashboard is a query per row. So "ready to review" means nothing is
 * missing from the document; the editor still has the final say.
 *
 * Ready drafts come first: they are one click from done.
 */
export function draftsNeedingWork(destinations: Destination[]): AttentionItem[] {
  return destinations
    .filter((d) => d.status === "draft")
    .map((d) => {
      const missing = readiness(d)
        .filter((r) => !r.ok)
        .map((r) => r.label.toLowerCase());
      return { d, missing };
    })
    .sort(
      (a, b) =>
        Number(a.missing.length > 0) - Number(b.missing.length > 0) ||
        ms(b.d.updatedAt) - ms(a.d.updatedAt),
    )
    .map(({ d, missing }) => ({
      key: `draft:${d.id}`,
      title: d.name.trim() || "Untitled destination",
      detail:
        missing.length === 0
          ? "Ready to review and publish."
          : `Before it can go live: ${missing.join(", ")}.`,
      href: `/destinations/${d.id}`,
      ready: missing.length === 0,
    }));
}

/**
 * Towns whose offline bundle is missing, behind the content, or incomplete.
 *
 * "Behind" is decided without running the function: the bundle's `version`
 * is a hash of its destination ids and their `updatedAt`, so it moves exactly
 * when the set of eligible places changes or one of them is edited after the
 * bundle was generated — both visible from here. The Bundles screen's *Check*
 * remains the authoritative answer; this is the reason to go and press it.
 *
 * The town set is the union of towns with eligible content and towns that
 * have a bundle, so a town whose last place was unpublished still shows up:
 * its bundle points phones at places they can no longer read.
 */
export function bundlesNeedingWork(
  destinations: Destination[],
  bundles: Map<string, OfflineBundle>,
): AttentionItem[] {
  // The same filter BundlesPage, the function and the tile extractor apply.
  const eligible = new Map<string, Destination[]>();
  for (const d of destinations) {
    if (d.status !== "published" || d.offlineEligible === false) continue;
    const town = d.town.trim();
    if (!town) continue;
    eligible.set(town, [...(eligible.get(town) ?? []), d]);
  }

  const byName = new Map([...bundles.values()].map((b) => [b.name, b]));
  const towns = [...new Set([...eligible.keys(), ...byName.keys()])].sort(
    (a, b) => a.localeCompare(b),
  );

  const items: AttentionItem[] = [];
  for (const town of towns) {
    const places = eligible.get(town) ?? [];
    const bundle = byName.get(town);
    const key = `bundle:${town}`;

    if (!bundle) {
      items.push({
        key,
        title: town,
        detail: `No offline bundle yet — ${places.length} place${places.length === 1 ? "" : "s"} phones cannot download.`,
        href: "/bundles",
      });
      continue;
    }

    const ids = places.map((d) => d.id).sort();
    const built = [...bundle.destinationIds].sort();
    const setChanged =
      ids.length !== built.length || ids.some((id, i) => id !== built[i]);
    const generated = ms(bundle.generatedAt);
    const editedSince =
      generated > 0 && places.some((d) => ms(d.updatedAt) > generated);

    if (setChanged || editedSince) {
      items.push({
        key,
        title: town,
        detail: "Changed since its bundle was built — rebuild so phones get the edits.",
        href: "/bundles",
      });
    } else if (bundle.status === "pending") {
      items.push({
        key,
        title: town,
        detail: "Bundle incomplete — files are missing from Storage, most often the map pack.",
        href: "/bundles",
      });
    }
  }
  return items;
}

/**
 * Tours that point at stops a visitor cannot see.
 *
 * A tour is public the moment it exists, but each stop is still a destination
 * behind the `status == 'published'` rule — so an unpublished or deleted stop
 * silently drops out of the tour on the phone, and the order the editor chose
 * stops being the order anyone walks.
 */
export function toursNeedingWork(
  tours: Tour[],
  destinations: Destination[],
): AttentionItem[] {
  const byId = new Map(destinations.map((d) => [d.id, d]));
  const items: AttentionItem[] = [];
  for (const t of tours) {
    let unpublished = 0;
    let deleted = 0;
    for (const id of t.stops) {
      const d = byId.get(id);
      if (!d) deleted++;
      else if (d.status !== "published") unpublished++;
    }
    const hidden = unpublished + deleted;
    if (hidden === 0) continue;

    const parts = [
      unpublished && `${unpublished} unpublished`,
      deleted && `${deleted} deleted`,
    ].filter(Boolean);
    items.push({
      key: `tour:${t.id}`,
      title: t.title,
      detail: `${hidden} of ${t.stops.length} stops hidden from visitors (${parts.join(", ")}).`,
      href: `/tours?edit=${encodeURIComponent(t.id)}`,
    });
  }
  return items;
}

// ---- formatting ------------------------------------------------------------

const rtf = new Intl.RelativeTimeFormat("en", { numeric: "auto" });

/**
 * "5 minutes ago", "yesterday", or a date once it is far enough back that
 * a relative phrase stops being easier to read than the date itself.
 */
export function relativeTime(at: number, now: number): string {
  const seconds = Math.round((at - now) / 1000);
  const abs = Math.abs(seconds);
  if (abs < 45) return "just now";
  if (abs < 60 * 45) return rtf.format(Math.round(seconds / 60), "minute");
  if (abs < 60 * 60 * 22) return rtf.format(Math.round(seconds / 3600), "hour");
  if (abs < 60 * 60 * 24 * 7) {
    return rtf.format(Math.round(seconds / 86400), "day");
  }
  // Day before month, as formatDate writes it: "1 Sep", never "Sep 1" on one
  // screen and "1 Sep 2026" on the next.
  const date = new Date(at);
  return shortDate(date, date.getFullYear() !== new Date(now).getFullYear());
}
