import { useId, useMemo, useState } from "react";
import {
  defaultRow,
  isPickable,
  suggestRows,
  type SuggestRow,
} from "../types/suggest";

/**
 * A field that offers the existing spelling before it accepts a new one.
 *
 * Shared by the town list, tags and subcategories — every one a list where a
 * near-duplicate is a defect. As you type it lists what you probably mean
 * (accents and small slips ignored); Enter takes the highlighted match. The
 * rules for what is listed and what Enter takes live in types/suggest.ts.
 *
 * A brand-new value is the last row. Where new values are routine (tags), it
 * is highlighted when nothing matches, so Enter adds it. Where they should be
 * rare (towns, which come from an official list), it never is: it takes a
 * deliberate click or arrow, and carries its warning.
 */
export function SuggestInput({
  candidates,
  existing = [],
  describe,
  allowNew = true,
  newWarning,
  newByDefault = true,
  normalizeNew = (s) => s.trim(),
  placeholder,
  label,
  commitKeys = ["Enter"],
  commitOnBlur = false,
  onPick,
}: {
  /** The names to suggest from. */
  candidates: readonly string[];
  /** Already chosen: shown as taken rather than offered again. */
  existing?: readonly string[];
  /** A short note beside a suggestion — "official", "3 places". */
  describe?: (value: string) => string | undefined;
  allowNew?: boolean;
  /** Said beside a new value, which is then never the default choice. */
  newWarning?: string;
  /** Whether Enter adds a new value when nothing matches. */
  newByDefault?: boolean;
  /** How a typed value is tidied before it is added. */
  normalizeNew?: (s: string) => string;
  placeholder?: string;
  /** Accessible name; the field usually sits under a visible heading. */
  label: string;
  /** Keys that take the highlighted row. Tags add a comma. */
  commitKeys?: string[];
  /**
   * Take the highlighted row when the field loses focus. For tags: typing one
   * and clicking away is the commonest way to add it, and losing it silently
   * was the old field's worst habit.
   */
  commitOnBlur?: boolean;
  onPick: (value: string, isNew: boolean) => void;
}) {
  const id = useId();
  const [text, setText] = useState("");
  const [open, setOpen] = useState(false);
  const [active, setActive] = useState<number | null>(null);

  const rows = useMemo(
    () =>
      suggestRows(text, {
        candidates,
        existing,
        describe,
        allowNew,
        normalizeNew,
      }),
    [text, candidates, existing, describe, allowNew, normalizeNew],
  );
  const current = active ?? defaultRow(rows, { newByDefault, newWarning });

  function pick(r: SuggestRow) {
    if (!isPickable(r)) return;
    onPick(r.value, r.kind === "new");
    setText("");
    setActive(null);
  }

  function move(step: 1 | -1) {
    const order = rows.flatMap((r, i) => (isPickable(r) ? [i] : []));
    if (order.length === 0) return;
    const at = current === null ? -1 : order.indexOf(current);
    setActive(order[(at + step + order.length) % order.length]);
  }

  const showList = open && rows.length > 0;
  const hasMatches = rows.some((r) => r.kind === "match");

  return (
    <div className="suggest">
      <input
        role="combobox"
        aria-label={label}
        aria-expanded={showList}
        aria-controls={`${id}-list`}
        aria-activedescendant={
          showList && current !== null ? `${id}-${current}` : undefined
        }
        aria-autocomplete="list"
        placeholder={placeholder}
        value={text}
        onChange={(e) => {
          setText(e.target.value);
          setActive(null);
          setOpen(true);
        }}
        onFocus={() => setOpen(true)}
        onBlur={() => {
          if (commitOnBlur && text.trim() && current !== null) {
            pick(rows[current]);
          }
          // Delayed so a click on an option lands before the list closes.
          setTimeout(() => setOpen(false), 120);
        }}
        onKeyDown={(e) => {
          if (e.key === "ArrowDown") {
            e.preventDefault();
            move(1);
          } else if (e.key === "ArrowUp") {
            e.preventDefault();
            move(-1);
          } else if (commitKeys.includes(e.key)) {
            e.preventDefault();
            if (current !== null) pick(rows[current]);
          } else if (e.key === "Escape") {
            setText("");
            setActive(null);
          }
        }}
      />
      {showList && (
        <ul className="suggest-list" role="listbox" id={`${id}-list`}>
          {rows.map((r, i) => (
            <li
              key={`${r.kind}:${r.value}`}
              id={`${id}-${i}`}
              role="option"
              aria-selected={i === current}
              aria-disabled={!isPickable(r)}
              className={[
                "suggest-row",
                i === current ? "on" : "",
                r.kind === "new" ? "new" : "",
                !isPickable(r) ? "taken" : "",
              ].join(" ")}
              // Keep focus in the field, so the click lands as a pick.
              onMouseDown={(e) => e.preventDefault()}
              onClick={() => pick(r)}
            >
              {r.kind === "taken" ? (
                <span>
                  <strong>{r.value}</strong> is already in the list
                </span>
              ) : r.kind === "new" ? (
                <>
                  <span>
                    Add <strong>“{r.value}”</strong>
                    {hasMatches ? " anyway" : ""}
                  </span>
                  {newWarning && (
                    <span className="suggest-note warn">{newWarning}</span>
                  )}
                </>
              ) : (
                <>
                  <span>
                    {r.corrects && !r.taken ? "Did you mean " : ""}
                    <strong>{r.value}</strong>
                    {r.corrects && !r.taken ? "?" : ""}
                  </span>
                  <span className="suggest-note">
                    {r.taken ? "already added" : r.note}
                  </span>
                </>
              )}
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}
