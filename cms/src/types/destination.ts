import type { Timestamp } from "firebase/firestore";

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
export const CAGAYAN_CENTRE = { lat: 17.6132, lng: 121.7270 };

/**
 * URL-safe slug from a name.
 *
 * Strips diacritics first so "Peñablanca" becomes "penablanca" rather than
 * losing the ñ entirely — several Cagayan place names carry them.
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

/**
 * Extra requirements to go live. Kept separate from [validate] so a draft can
 * be saved incomplete — an editor should be able to stop halfway.
 */
export function publishBlockers(d: Omit<Destination, "id">): string[] {
  const blockers = Object.values(validate(d));
  if (d.images.length === 0) {
    blockers.push("Add at least one photo — the card has no fallback image.");
  }
  return blockers;
}
