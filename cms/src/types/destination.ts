import type { Timestamp } from "firebase/firestore";
import { segmentProblems, type SegmentDraft } from "./segment";

/**
 * Mirrors `docs/DATA_MODEL.md` and `lib/core/models/destination.dart`.
 *
 * Three representations of one contract. When the schema changes, all three
 * move together — that is why the CMS lives in this repo (D-10).
 */
export const DESTINATION_SCHEMA_VERSION = 2;

export const CATEGORIES = [
  "church",
  "nature",
  "heritage",
  "museum",
  "food",
  "landmark",
] as const;
export type Category = (typeof CATEGORIES)[number];

export const CATEGORY_LABELS: Record<Category, string> = {
  church: "Church",
  nature: "Nature",
  heritage: "Heritage",
  museum: "Museum",
  food: "Food",
  landmark: "Landmark",
};

export type Status = "draft" | "published";

export type PracticalInfo = {
  entryFee?: string;
  openHours?: string;
  bestSeason?: string;
  accessibility?: string;
};

export type Destination = {
  id: string;
  name: string;
  slug: string;
  town: string;
  category: Category;
  /** Card and detail intro. Capped at 140 characters — see MAX_DESCRIPTION. */
  description: string;
  history?: string;
  coords: { lat: number; lng: number };
  /** Storage paths. The first is the card image. */
  images: string[];
  popular: boolean;
  featured: boolean;
  nearbyEligible: boolean;
  offlineEligible: boolean;
  isMuseum: boolean;
  hasAR: boolean;
  tags: string[];
  practical?: PracticalInfo;
  status: Status;
  schemaVersion: number;
  createdAt?: Timestamp;
  updatedAt?: Timestamp;
  updatedBy?: string;
};

/** The wireframe states this limit; the card layout depends on it. */
export const MAX_DESCRIPTION = 140;

/** Cagayan's approximate centre — where a new destination's pin starts. */
export const CAGAYAN_CENTRE = { lat: 17.6132, lng: 121.727 };

/**
 * URL-safe slug from a name.
 *
 * Strips diacritics first so "Peñablanca" becomes "penablanca" rather than
 * losing the ñ entirely — several Cagayan place names carry them.
 *
 * **`scripts/lib/slug.mjs` must produce the same string for the same input.**
 * The CMS derives the slug when a destination is created; `import-content.mjs`
 * re-derives it to decide whether a spreadsheet row is a destination that
 * already exists. One character of disagreement and a re-import stops
 * recognising them, creating a second copy of the province instead of updating
 * it.
 *
 * The two cannot share code across the TypeScript/Node boundary, so they share
 * a fixture instead: `scripts/lib/slug-cases.json`, asserted by `slug.test.ts`
 * beside this file and by `scripts/lib/slug.test.mjs`. Change the behaviour
 * here and both suites fail until the fixture is updated too.
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

/** A blank destination, ready for the editor. */
export function emptyDestination(): Omit<Destination, "id"> {
  return {
    name: "",
    slug: "",
    town: "",
    category: "nature",
    description: "",
    coords: { ...CAGAYAN_CENTRE },
    images: [],
    popular: false,
    featured: false,
    nearbyEligible: true,
    offlineEligible: true,
    isMuseum: false,
    hasAR: false,
    tags: [],
    status: "draft",
    schemaVersion: DESTINATION_SCHEMA_VERSION,
  };
}

/** Blocking problems, keyed by field. Empty means publishable. */
export function validate(d: Omit<Destination, "id">): Record<string, string> {
  const errors: Record<string, string> = {};
  if (!d.name.trim()) errors.name = "Required.";
  if (!d.slug.trim()) errors.slug = "Required.";
  if (!d.town.trim()) errors.town = "Required.";
  if (!d.description.trim()) errors.description = "Required.";
  if (d.description.length > MAX_DESCRIPTION) {
    errors.description = `Max ${MAX_DESCRIPTION} characters.`;
  }
  if (!Number.isFinite(d.coords.lat) || !Number.isFinite(d.coords.lng)) {
    errors.coords = "Set a location.";
  }
  return errors;
}

export type ReadinessItem = {
  label: string;
  ok: boolean;
  /** Which tab to send the editor to when this is the thing that is missing. */
  tab: "details" | "location" | "media" | "audio";
  /** Shown when `ok` is false. */
  why?: string;
};

/**
 * Everything required to publish, as a checklist.
 *
 * Single source for both the checklist UI and [publishBlockers], so the button
 * can never be disabled for a reason the checklist does not show — which is
 * exactly what a `title` tooltip on a disabled button used to do.
 *
 * Segments are passed in rather than read here: they live in a subcollection,
 * so they are not part of the destination document this module otherwise
 * describes. They contribute checks only when the guide has stops at all — an
 * audio guide is optional, but a half-built one must not go live.
 */
export function readiness(
  d: Omit<Destination, "id">,
  segments: SegmentDraft[] = [],
): ReadinessItem[] {
  const desc = d.description.trim();
  const { untitled, silent } = segmentProblems(segments);
  return [
    { label: "Name", ok: d.name.trim() !== "", tab: "details" },
    { label: "Slug", ok: d.slug.trim() !== "", tab: "details" },
    { label: "Town", ok: d.town.trim() !== "", tab: "details" },
    {
      label: "Description",
      ok: desc !== "" && desc.length <= MAX_DESCRIPTION,
      tab: "details",
      why:
        desc === ""
          ? "Needed for the card."
          : `Over ${MAX_DESCRIPTION} characters.`,
    },
    {
      label: "Location",
      ok:
        Number.isFinite(d.coords.lat) &&
        Number.isFinite(d.coords.lng) &&
        !(d.coords.lat === 0 && d.coords.lng === 0),
      tab: "location",
      why: "Set the coordinates.",
    },
    {
      label: "At least one photo",
      ok: d.images.length > 0,
      tab: "media",
      why: "The card has no fallback image.",
    },
    // Only meaningful once a guide exists. A destination with no segments is
    // perfectly publishable — most of them have no narration at all.
    ...(segments.length > 0
      ? [
          {
            label: "Every stop is named",
            ok: untitled === 0,
            tab: "audio" as const,
            why: `${untitled} stop${untitled === 1 ? " has" : "s have"} no title.`,
          },
          {
            label: "Every stop can be played",
            ok: silent === 0,
            tab: "audio" as const,
            why: `${silent} stop${silent === 1 ? " has" : "s have"} neither a recording nor narration text — the player skips them in silence.`,
          },
        ]
      : []),
  ];
}

/**
 * Extra requirements to go live. Kept separate from [validate] so a draft can
 * be saved incomplete — an editor should be able to stop halfway.
 */
export function publishBlockers(
  d: Omit<Destination, "id">,
  segments: SegmentDraft[] = [],
): string[] {
  return readiness(d, segments)
    .filter((r) => !r.ok)
    .map((r) => (r.why ? `${r.label} — ${r.why}` : `${r.label} is required.`));
}
