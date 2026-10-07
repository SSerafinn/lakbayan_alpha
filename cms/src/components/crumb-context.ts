import { createContext, useContext, useEffect } from "react";

/**
 * Lets a screen name the item it is showing, so the top bar can read
 * "Destinations / Callao Cave" rather than the section alone.
 *
 * The shell owns the bar, and the shell does not know what an id means; the
 * editor does. This is the one piece of state that crosses that line.
 */
export const CrumbContext = createContext<(label: string | null) => void>(
  () => {},
);

/** Name the current item in the top bar for as long as this screen is open. */
export function useCrumb(label: string | null) {
  const set = useContext(CrumbContext);
  useEffect(() => {
    set(label);
    return () => set(null);
  }, [label, set]);
}

// Separate from the shell on purpose, as auth-context.ts is: Fast Refresh only
// handles a module that exports components exclusively.
