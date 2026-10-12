/**
 * "Did you mean …?" for the CMS's pick-a-name fields: towns, tags and
 * subcategories. Every one of them is a list where a near-duplicate is a
 * real defect — "Penablanca" beside "Peñablanca" splits a town's offline
 * bundle; "cave" beside "caves" splits a tag — so the field offers the
 * existing spelling before it accepts a new one.
 */

/** Lowercase, accents off, runs of spaces and hyphens as one space. */
export function fold(s: string): string {
  return s
    .normalize("NFD")
    .replace(/[̀-ͯ]/g, "")
    .toLowerCase()
    .replace(/[\s\-_]+/g, " ")
    .trim();
}

/**
 * Edit distance between two strings, counting a swap of neighbours as one
 * edit ("Peñalbanca") — the commonest typing slip.
 */
export function distance(a: string, b: string): number {
  const d: number[][] = Array.from({ length: a.length + 1 }, (_, i) =>
    Array.from({ length: b.length + 1 }, (_, j) => (i === 0 ? j : j === 0 ? i : 0)),
  );
  for (let i = 1; i <= a.length; i++) {
    for (let j = 1; j <= b.length; j++) {
      const cost = a[i - 1] === b[j - 1] ? 0 : 1;
      d[i][j] = Math.min(d[i - 1][j] + 1, d[i][j - 1] + 1, d[i - 1][j - 1] + cost);
      if (i > 1 && j > 1 && a[i - 1] === b[j - 2] && a[i - 2] === b[j - 1]) {
        d[i][j] = Math.min(d[i][j], d[i - 2][j - 2] + 1);
      }
    }
  }
  return d[a.length][b.length];
}

/** How many slips a word of this length may carry and still be "meant". */
function tolerance(length: number): number {
  return length <= 3 ? 0 : length <= 6 ? 1 : length <= 10 ? 2 : 3;
}

export type Match = {
  value: string;
  /** exact: the same word, ignoring case and accents. */
  kind: "exact" | "prefix" | "close";
};

/**
 * Candidates the input may mean, best first: the same name written
 * differently, then names it starts, then names a slip or two away.
 */
export function suggest(
  input: string,
  candidates: readonly string[],
  limit = 6,
): Match[] {
  const q = fold(input);
  if (!q) return [];
  const scored: { m: Match; rank: number; d: number }[] = [];
  for (const value of candidates) {
    const c = fold(value);
    if (c === q) {
      scored.push({ m: { value, kind: "exact" }, rank: 0, d: 0 });
    } else if (c.startsWith(q) || c.split(" ").some((w) => w.startsWith(q))) {
      scored.push({ m: { value, kind: "prefix" }, rank: 1, d: c.length - q.length });
    } else {
      // Compare against the candidate's own length too, so "tuguegarao"
      // still finds "Tuguegarao City".
      const d = Math.min(distance(q, c), distance(q, c.slice(0, q.length + 1)));
      if (d <= tolerance(Math.max(q.length, 4))) {
        scored.push({ m: { value, kind: "close" }, rank: 2, d });
      }
    }
  }
  return scored
    .sort((a, b) => a.rank - b.rank || a.d - b.d || a.m.value.localeCompare(b.m.value))
    .slice(0, limit)
    .map((s) => s.m);
}

/**
 * A new name's capitals, for a field that holds proper nouns: the first
 * letter of each word up, the rest as typed. "santa ana" → "Santa Ana",
 * "lal-lo" → "Lal-lo" (only after a space, so the official hyphenated
 * spelling is not mangled).
 */
export function capitalise(s: string): string {
  return s
    .trim()
    .replace(/\s+/g, " ")
    .replace(/(^|\s)(\p{L})/gu, (_, sp: string, ch: string) => sp + ch.toUpperCase());
}
