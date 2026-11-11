import { useEffect, useRef } from "react";
import type { SelectionState } from "../types/list";

/**
 * The checkbox in a table's header: ticks every row on screen, or clears
 * them, and shows a dash while only some are ticked.
 *
 * `indeterminate` is a DOM property with no HTML attribute, so it has to be
 * set on the element; React has no prop for it.
 */
export function SelectAll({
  state,
  onToggle,
  noun,
}: {
  state: SelectionState;
  onToggle: () => void;
  /** What the rows are, plural: "places", "guides". */
  noun: string;
}) {
  const ref = useRef<HTMLInputElement>(null);
  useEffect(() => {
    if (ref.current) ref.current.indeterminate = state === "some";
  }, [state]);

  return (
    <input
      ref={ref}
      type="checkbox"
      checked={state === "all"}
      onChange={onToggle}
      aria-label={
        state === "all" ? `Clear the selected ${noun}` : `Select all ${noun} shown`
      }
    />
  );
}
