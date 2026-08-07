/**
 * Municipalities and cities of the Province of Cagayan.
 *
 * These are **suggestions, not a restriction** — the town field stays free text
 * and this only backs its `<datalist>`. A missing or misspelt entry here must
 * never block an editor from saving.
 *
 * Why a fixed list rather than deriving one from existing documents: `town` is
 * the grouping key for offline bundles (Phase 3). "Peñablanca" and "Penablanca"
 * silently become two towns, two bundles, and destinations that vanish from the
 * wrong one. A derived list only helps *after* somebody has already typed it
 * correctly once, which is exactly too late.
 *
 * TODO(CMS-4): Settings → Taxonomy takes ownership of this, so the province can
 * correct it without a deploy. Verify against the official PSGC listing then.
 */
export const CAGAYAN_TOWNS = [
  "Abulug",
  "Alcala",
  "Allacapan",
  "Amulung",
  "Aparri",
  "Baggao",
  "Ballesteros",
  "Buguey",
  "Calayan",
  "Camalaniugan",
  "Claveria",
  "Enrile",
  "Gattaran",
  "Gonzaga",
  "Iguig",
  "Lal-lo",
  "Lasam",
  "Pamplona",
  "Peñablanca",
  "Piat",
  "Rizal",
  "Sanchez-Mira",
  "Santa Ana",
  "Santa Praxedes",
  "Santa Teresita",
  "Santo Niño",
  "Solana",
  "Tuao",
  "Tuguegarao City",
] as const;
