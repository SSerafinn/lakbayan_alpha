import { useCallback, useState } from "react";

const PREFIX = "lakbayan-cms:";

function read(key: string): boolean | null {
  try {
    const raw = window.localStorage.getItem(PREFIX + key);
    return raw === null ? null : raw === "1";
  } catch {
    // Storage can be blocked or full; the flag then lasts for this visit only.
    return null;
  }
}

/**
 * A yes/no this browser remembers between visits: a preference about how the
 * CMS looks to one person, never content and never anything another admin
 * should see.
 */
export function useStoredFlag(
  key: string,
  initial: boolean,
): [boolean, (value: boolean) => void] {
  const [value, setValue] = useState(() => read(key) ?? initial);
  const set = useCallback(
    (next: boolean) => {
      setValue(next);
      try {
        window.localStorage.setItem(PREFIX + key, next ? "1" : "0");
      } catch {
        // See `read`.
      }
    },
    [key],
  );
  return [value, set];
}
