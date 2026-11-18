import glyphData from "../../../design/category-glyphs.json";
import { CATEGORIES, CATEGORY_LABELS, slugify, type Category } from "./destination";

/**
 * Categories: the six built in, plus any the province adds in Settings.
 *
 * The six have their own glyph and colours in the app. One added in Settings
 * is stored in `settings/taxonomy.categories` with an icon from a fixed list
 * (`design/category-glyphs.json`, which the app transcribes) and a `look`:
 * the colours of one of the six. A destination's `category` holds either a
 * built-in id or an added one's `id`. Mirrors `docs/DATA_MODEL.md`.
 */

export type CategoryGlyph = { name: string; label: string; codepoint: number };

export const CATEGORY_GLYPHS: readonly CategoryGlyph[] = glyphData.glyphs.map(
  (g) => ({ name: g.name, label: g.label, codepoint: parseInt(g.codepoint, 16) }),
);

const GLYPH_BY_NAME = new Map(CATEGORY_GLYPHS.map((g) => [g.name, g]));

/** `AppIcons.kind` in the app: the same codepoint in both weights. */
export const BUILT_IN_GLYPH: Record<Category, number> = {
  nature: 0xe7ae,
  food: 0xe262,
  church: 0xecea,
  heritage: 0xe9d0,
  museum: 0xe0b4,
  landmark: 0xe244,
};

/** The app's `DestinationCategory.label`, used on its chips. */
export const BUILT_IN_PLURAL: Record<Category, string> = {
  church: "Churches",
  nature: "Nature",
  heritage: "Heritage",
  museum: "Museums",
  food: "Food",
  landmark: "Landmarks",
};

/** The app's glyph for a category it cannot place (`unknown`). */
export const OTHER_GLYPH = 0xe316;

/** `settings/taxonomy.categories[]`. */
export type CustomCategory = {
  /** Stored on destinations; fixed once created. */
  id: string;
  /** One place, as the app reads it: "Resort in Santa Ana". */
  name: string;
  /** On the app's chips: "Resorts". */
  plural: string;
  /** A name from `CATEGORY_GLYPHS`. */
  glyph: string;
  /** Whose colours it takes. */
  look: Category;
};

/** One category, built in or added, as every screen needs it. */
export type CategoryInfo = {
  id: string;
  name: string;
  plural: string;
  codepoint: number;
  look: Category;
  builtIn: boolean;
};

export const MAX_CUSTOM_CATEGORIES = 12;

/** Ids an added category may never take. */
const RESERVED = new Set<string>([...CATEGORIES, "unknown", "all", "other"]);

export function isBuiltIn(id: string): id is Category {
  return (CATEGORIES as readonly string[]).includes(id);
}

export function glyphCodepoint(name: string): number | null {
  return GLYPH_BY_NAME.get(name)?.codepoint ?? null;
}

/** The six, then the added ones in the order they were added. */
export function allCategories(custom: readonly CustomCategory[]): CategoryInfo[] {
  return [
    ...CATEGORIES.map((c) => ({
      id: c,
      name: CATEGORY_LABELS[c],
      plural: BUILT_IN_PLURAL[c],
      codepoint: BUILT_IN_GLYPH[c],
      look: c,
      builtIn: true,
    })),
    ...custom.map((c) => ({
      id: c.id,
      name: c.name,
      plural: c.plural,
      codepoint: glyphCodepoint(c.glyph) ?? OTHER_GLYPH,
      look: c.look,
      builtIn: false,
    })),
  ];
}

/** One category by id, or null for one that no longer exists. */
export function categoryInfo(
  id: string,
  custom: readonly CustomCategory[],
): CategoryInfo | null {
  return allCategories(custom).find((c) => c.id === id) ?? null;
}

/** A category's name for a label, falling back to its raw id. */
export function categoryName(id: string, custom: readonly CustomCategory[]): string {
  return categoryInfo(id, custom)?.name ?? id;
}

/** The id a new category with this name would get. */
export function categoryIdFor(name: string): string {
  return slugify(name);
}

/** Simple English plural, for the plural field's starting value. */
export function suggestPlural(name: string): string {
  const n = name.trim();
  if (!n) return "";
  if (/[^aeiou]y$/i.test(n)) return `${n.slice(0, -1)}ies`;
  if (/(s|x|z|ch|sh)$/i.test(n)) return `${n}es`;
  return `${n}s`;
}

/**
 * What stops this category from being saved, or null. `others` is every
 * other added category, so the id and name are checked as free.
 */
export function categoryProblem(
  c: CustomCategory,
  others: readonly CustomCategory[],
): string | null {
  const name = c.name.trim();
  if (!name) return "Give it a name.";
  if (!c.plural.trim()) return "Give it a plural, for the app's chips.";
  if (!c.id) return "The name needs a letter or a number in it.";
  if (RESERVED.has(c.id)) return `“${name}” is already one of the six.`;
  const builtInNames = CATEGORIES.map((b) => slugify(CATEGORY_LABELS[b]));
  if (builtInNames.includes(slugify(name))) return `“${name}” is already one of the six.`;
  if (others.some((o) => o.id === c.id || slugify(o.name) === slugify(name))) {
    return `There is already a category called “${name}”.`;
  }
  if (!GLYPH_BY_NAME.has(c.glyph)) return "Pick an icon.";
  if (!isBuiltIn(c.look)) return "Pick the colours it takes.";
  return null;
}

/** Tidied for storage: trimmed, and anything unsaveable dropped. */
export function cleanCategories(list: readonly CustomCategory[]): CustomCategory[] {
  const out: CustomCategory[] = [];
  for (const c of list) {
    const tidy = { ...c, name: c.name.trim(), plural: c.plural.trim() };
    if (!categoryProblem(tidy, out)) out.push(tidy);
  }
  return out;
}

/** How many destinations use each category id. */
export function categoryUsage(
  destinations: readonly { category: string }[],
): Map<string, number> {
  const counts = new Map<string, number>();
  for (const d of destinations) counts.set(d.category, (counts.get(d.category) ?? 0) + 1);
  return counts;
}
