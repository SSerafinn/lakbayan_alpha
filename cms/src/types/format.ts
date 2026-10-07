import type { Timestamp } from "firebase/firestore";

/**
 * A date as "7 Oct 2026", whatever the browser's locale.
 *
 * Not `toLocaleDateString()` with no arguments, which is what the lists used:
 * on a Philippine machine it printed 7 October 2026 as "07/10/2026", and in the
 * Philippines that reads as the tenth of July. A month spelled out cannot be
 * misread in either order.
 */
export function formatDate(t?: Timestamp | Date | null): string {
  if (!t) return "—";
  return shortDate(t instanceof Date ? t : t.toDate(), true);
}

// A fixed list, not `toLocaleDateString`: ICU's own abbreviations change
// between versions ("Sep" became "Sept" in en-GB), so the same date could
// print two ways on two machines.
const MONTHS = [
  "Jan", "Feb", "Mar", "Apr", "May", "Jun",
  "Jul", "Aug", "Sep", "Oct", "Nov", "Dec",
];

/** "7 Oct", or "7 Oct 2026" with the year. Local time, as the admin sees it. */
export function shortDate(date: Date, withYear: boolean): string {
  const dm = `${date.getDate()} ${MONTHS[date.getMonth()]}`;
  return withYear ? `${dm} ${date.getFullYear()}` : dm;
}
