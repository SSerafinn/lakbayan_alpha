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
  const date = t instanceof Date ? t : t.toDate();
  return date.toLocaleDateString("en-GB", {
    day: "numeric",
    month: "short",
    year: "numeric",
  });
}
