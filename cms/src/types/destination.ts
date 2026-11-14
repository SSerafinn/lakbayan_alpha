import type { Timestamp } from "firebase/firestore";
import { countExhibitProblems, type ExhibitDraft } from "./exhibit";
import { segmentProblems, type SegmentDraft } from "./segment";

/**
 * Mirrors `docs/DATA_MODEL.md` and `lib/core/models/destination.dart`.
 *
 * Three representations of one contract. When the schema changes, all three
 * move together — that is why the CMS lives in this repo (D-10).
 */
export const DESTINATION_SCHEMA_VERSION = 4;

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
  /**
   * A finer kind within the category, from Settings → Taxonomy. Null for
   * none — never undefined, which Firestore refuses to write.
   */
  subcategory?: string | null;
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
  /**
   * Derived, never edited: set on every save from whether a museum has an
   * exhibit the scanner can find (`museumHasAR`, D-18).
   */
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
 * Nobody has placed the pin yet: a new destination starts at the province's
 * centre, and an old document or a cleared field can hold 0,0 or no number.
 *
 * The centre used to count as a location, so a new place passed "Location"
 * before anyone touched its map, and could go live pinned to the middle of
 * the province.
 */
export function pinUnset({ lat, lng }: { lat: number; lng: number }): boolean {
  return (
    !Number.isFinite(lat) ||
    !Number.isFinite(lng) ||
    (lat === 0 && lng === 0) ||
    (lat === CAGAYAN_CENTRE.lat && lng === CAGAYAN_CENTRE.lng)
  );
}

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
    subcategory: null,
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
  tab: "details" | "location" | "media" | "audio" | "ar";
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
 * Segments and exhibits are passed in rather than read here: they live in
 * subcollections, so they are not part of the destination document this module
 * otherwise describes. They contribute checks only when there are any — an
 * audio guide and AR are optional, but a half-built one must not go live.
 * Exhibits count only on a museum, the one place the app looks for them.
 */
export function readiness(
  d: Omit<Destination, "id">,
  segments: SegmentDraft[] = [],
  exhibits: ExhibitDraft[] = [],
): ReadinessItem[] {
  const desc = d.description.trim();
  const { untitled, silent } = segmentProblems(segments);
  const exhibitCounts = countExhibitProblems(exhibits);
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
      ok: !pinUnset(d.coords),
      tab: "location",
      why: "Place the pin on the map.",
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
    ...(d.isMuseum && exhibits.length > 0
      ? [
          {
            label: "Every exhibit is named",
            ok: exhibitCounts.untitled === 0,
            tab: "ar" as const,
            why: `${exhibitCounts.untitled} exhibit${exhibitCounts.untitled === 1 ? " has" : "s have"} no title — the card the camera shows would be blank.`,
          },
          {
            label: "Every exhibit has a marker",
            ok: exhibitCounts.unmarked === 0,
            tab: "ar" as const,
            why: `${exhibitCounts.unmarked} exhibit${exhibitCounts.unmarked === 1 ? " is" : "s are"} missing a marker photo or its real width — the camera cannot look for ${exhibitCounts.unmarked === 1 ? "it" : "them"}.`,
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
  exhibits: ExhibitDraft[] = [],
): string[] {
  return readiness(d, segments, exhibits)
    .filter((r) => !r.ok)
    .map((r) => (r.why ? `${r.label} — ${r.why}` : `${r.label} is required.`));
}
