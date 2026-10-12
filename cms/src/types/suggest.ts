import { fold, suggest } from "./fuzzy";

/**
 * What the pick-a-name field lists for what has been typed, and which row
 * Enter takes. Pure, so the rules that stop a mistake are tested, not just
 * looked at — see SuggestInput.
 */
export type SuggestRow =
  | {
      kind: "match";
      value: string;
      note?: string;
      /** Already chosen: shown, not offered. */
      taken: boolean;
      /** A correction of what was typed, rather than a completion of it. */
      corrects: boolean;
    }
  | { kind: "taken"; value: string }
  | { kind: "new"; value: string };

export function suggestRows(
  text: string,
  {
    candidates,
    existing = [],
    describe,
    allowNew = true,
    normalizeNew = (s) => s.trim(),
  }: {
    candidates: readonly string[];
    existing?: readonly string[];
    describe?: (value: string) => string | undefined;
    allowNew?: boolean;
    normalizeNew?: (s: string) => string;
  },
): SuggestRow[] {
  const q = text.trim();
  if (!q) return [];
  const taken = new Set(existing.map(fold));
  // Suggest from what is known and what is already chosen, so typing a name
  // that is already there says so instead of offering to add it again.
  const pool = [...new Set([...candidates, ...existing])];
  const matches = suggest(q, pool);
  const exact = matches.find((m) => m.kind === "exact");
  if (exact && taken.has(fold(exact.value))) {
    return [{ kind: "taken", value: exact.value }];
  }
  const rows: SuggestRow[] = matches.map((m) => ({
    kind: "match",
    value: m.value,
    note: describe?.(m.value),
    taken: taken.has(fold(m.value)),
    corrects: m.kind === "close" || (m.kind === "exact" && m.value !== q),
  }));
  if (allowNew && !exact) {
    const value = normalizeNew(q);
    if (value && !taken.has(fold(value))) rows.push({ kind: "new", value });
  }
  return rows;
}

export function isPickable(r: SuggestRow): boolean {
  return r.kind === "new" || (r.kind === "match" && !r.taken);
}

/**
 * The row Enter takes when nothing has been arrowed to: the first match not
 * already chosen. Failing that, the new value — but only where new values
 * are routine (`newByDefault`) and carry no warning. A town that is not on
 * the official list is never one keypress away.
 */
export function defaultRow(
  rows: SuggestRow[],
  { newByDefault = true, newWarning }: { newByDefault?: boolean; newWarning?: string } = {},
): number | null {
  const match = rows.findIndex((r) => r.kind === "match" && !r.taken);
  if (match >= 0) return match;
  const fresh = rows.findIndex((r) => r.kind === "new");
  return fresh >= 0 && newByDefault && !newWarning ? fresh : null;
}
