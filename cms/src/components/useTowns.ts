import { useEffect, useState } from "react";
import { getSettings } from "../lib/settings";
import { CAGAYAN_TOWNS } from "../types/towns";
import type { TaxonomySettings } from "../types/settings";

// Read once per page load and shared: the destination editor asks on every
// open, and the list changes a few times a year.
let cache: Promise<string[]> | null = null;

function load(): Promise<string[]> {
  cache ??= getSettings<TaxonomySettings>("taxonomy")
    .then(({ data }) =>
      data?.towns?.length ? data.towns : [...CAGAYAN_TOWNS],
    )
    .catch(() => {
      cache = null;
      return [...CAGAYAN_TOWNS];
    });
  return cache;
}

/** Forget the cached list — after Settings saves a new one. */
export function refreshTowns() {
  cache = null;
}

/**
 * The municipality list to offer for a destination's town: the province's,
 * from Settings, or the built-in one until anyone has saved it.
 */
export function useTowns(): readonly string[] {
  const [towns, setTowns] = useState<readonly string[]>(CAGAYAN_TOWNS);
  useEffect(() => {
    let live = true;
    void load().then((t) => live && setTowns(t));
    return () => {
      live = false;
    };
  }, []);
  return towns;
}
