import type { MouseEvent } from "react";

/**
 * Lets a table row open its item from anywhere on it, after Polaris's index
 * tables: the name was the only way in, and a click on the photo or the
 * status beside it did nothing.
 *
 * The name stays a real link or button, which is what the keyboard and a
 * screen reader use; this is the pointer's shortcut to the same place. It
 * stands aside for anything in the row with a job of its own (the tick box
 * and its cell, a button, a link) and for a drag that selected text.
 */
export function onRowClick(open: (e: MouseEvent<HTMLTableRowElement>) => void) {
  return (e: MouseEvent<HTMLTableRowElement>) => {
    if (e.defaultPrevented) return;
    const target = e.target as HTMLElement;
    if (target.closest("a, button, input, select, label, .tick")) return;
    if (window.getSelection()?.toString()) return;
    open(e);
  };
}
