import {
  CATEGORIES,
  readiness,
  type Category,
  type Destination,
  type Status,
} from "./destination";
import type { ExhibitDraft } from "./exhibit";
import type { SegmentDraft } from "./segment";

/**
 * What the Destinations list is showing, and what a bulk action on it will
 * do. Pure, so the list's rules can be tested without a browser.
 */

/**
 * Saved views across the top of the table, after Polaris's index pages.
 *
 * They replace the status dropdown: "what is still a draft?" and "what has
 * no photo?" are the two questions this screen gets asked most, and a view
 * answers each with one click and a count. "Needs a photo" is the most common
 * reason a draft cannot be published.
 */
export type DestinationView = "all" | "published" | "draft" | "no-photo";

export const DESTINATION_VIEWS: {
  id: DestinationView;
  label: string;
  test: (d: Destination) => boolean;
}[] = [
  { id: "all", label: "All", test: () => true },
  { id: "published", label: "Published", test: (d) => d.status === "published" },
  { id: "draft", label: "Drafts", test: (d) => d.status === "draft" },
  { id: "no-photo", label: "Needs a photo", test: (d) => d.images.length === 0 },
];

export type DestinationFilters = {
  view: DestinationView;
  search: string;
  town: string;
  category: Category | "all";
};

export const NO_FILTERS: DestinationFilters = {
  view: "all",
  search: "",
  town: "all",
  category: "all",
};

/**
 * The list's filters from its address.
 *
 * They live in the URL rather than in component state so that Back from a
 * place returns to the list as it was left, and a filtered list can be
 * linked to. Anything unrecognised reads as "no filter": an old or mistyped
 * link shows everything rather than an empty table.
 */
export function readFilters(params: URLSearchParams): DestinationFilters {
  const view = params.get("view");
  const category = params.get("category");
  return {
    view: DESTINATION_VIEWS.some((v) => v.id === view)
      ? (view as DestinationView)
      : "all",
    search: params.get("q") ?? "",
    town: params.get("town") || "all",
    category: (CATEGORIES as readonly string[]).includes(category ?? "")
      ? (category as Category)
      : "all",
  };
}

/** The address for those filters: only what is set, so a plain list keeps a plain URL. */
export function writeFilters(f: DestinationFilters): URLSearchParams {
  const params = new URLSearchParams();
  if (f.view !== "all") params.set("view", f.view);
  if (f.search !== "") params.set("q", f.search);
  if (f.town !== "all") params.set("town", f.town);
  if (f.category !== "all") params.set("category", f.category);
  return params;
}

export function applyFilters(
  rows: Destination[],
  f: DestinationFilters,
): Destination[] {
  const q = f.search.trim().toLowerCase();
  const view = DESTINATION_VIEWS.find((v) => v.id === f.view)!;
  return rows.filter(
    (r) =>
      (!q ||
        r.name.toLowerCase().includes(q) ||
        r.town.toLowerCase().includes(q)) &&
      (f.town === "all" || r.town === f.town) &&
      (f.category === "all" || r.category === f.category) &&
      view.test(r),
  );
}

/** How much of what is on screen is ticked: drives the header checkbox. */
export type SelectionState = "none" | "some" | "all";

export function selectionState(
  visible: string[],
  selected: ReadonlySet<string>,
): SelectionState {
  const n = visible.filter((id) => selected.has(id)).length;
  if (n === 0) return "none";
  return n === visible.length ? "all" : "some";
}

/**
 * The header checkbox: tick every row on screen, or clear them if they all
 * are. Rows a filter is hiding keep whatever they had.
 */
export function toggleAll(
  visible: string[],
  selected: ReadonlySet<string>,
): Set<string> {
  const next = new Set(selected);
  if (selectionState(visible, selected) === "all") {
    for (const id of visible) next.delete(id);
  } else {
    for (const id of visible) next.add(id);
  }
  return next;
}

/** A place's audio guide and exhibits, which also decide whether it can go live. */
export type Subcollections = {
  segments: SegmentDraft[];
  exhibits: ExhibitDraft[];
};

export type BulkStatusPlan = {
  /** What will be written, with the status each had, so it can be undone. */
  change: { id: string; from: Status }[];
  /** Asked to publish but not ready: left alone, and named with what is missing. */
  blocked: { id: string; name: string; missing: string[] }[];
};

/**
 * What "Publish" or "Unpublish" on the ticked rows will do.
 *
 * A place already in that state is skipped: writing it again would move its
 * "last edited" for nothing and tell anyone with it open that it changed.
 * Publishing holds each place to the same `readiness` list as the editor's
 * Publish button. The list wrote the status straight through before, so a
 * place with no photo could go live from here and not from its own page.
 */
export function planBulkStatus(
  rows: Destination[],
  ids: ReadonlySet<string>,
  next: Status,
  subcollections: ReadonlyMap<string, Subcollections> = new Map(),
): BulkStatusPlan {
  const plan: BulkStatusPlan = { change: [], blocked: [] };
  for (const d of rows) {
    if (!ids.has(d.id) || d.status === next) continue;
    if (next === "published") {
      const sub = subcollections.get(d.id);
      const missing = readiness(d, sub?.segments, sub?.exhibits)
        .filter((r) => !r.ok)
        .map((r) => r.label);
      if (missing.length > 0) {
        plan.blocked.push({
          id: d.id,
          name: d.name || "Untitled destination",
          missing,
        });
        continue;
      }
    }
    plan.change.push({ id: d.id, from: d.status });
  }
  return plan;
}

/** The toast after a bulk action: what happened, and what was left alone and why. */
export function bulkStatusMessage(
  plan: BulkStatusPlan,
  next: Status,
): { title: string; description?: string } {
  const n = plan.change.length;
  const places = (count: number) => `${count} place${count === 1 ? "" : "s"}`;
  const verb = next === "published" ? "published" : "unpublished";
  const title =
    n === 0
      ? plan.blocked.length > 0
        ? "Nothing was published"
        : `Already ${verb}`
      : `${places(n)} ${verb}`;
  if (plan.blocked.length === 0) return { title };
  const first = plan.blocked[0];
  const rest = plan.blocked.length - 1;
  return {
    title,
    description: `${first.name} is not ready: ${first.missing.join(", ").toLowerCase()}.${
      rest > 0 ? ` So ${rest === 1 ? "is 1 other" : `are ${rest} others`}.` : ""
    }`,
  };
}
