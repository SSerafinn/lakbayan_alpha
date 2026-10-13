import { useEffect, useState } from "react";
import { getSettings } from "../lib/settings";
import { CAGAYAN_TOWNS } from "../types/towns";
import type { TaxonomySettings } from "../types/settings";

// Read once per page load and shared: the destination editor asks on every
// open, and the lists change a few times a year.
let cache: Promise<TaxonomySettings> | null = null;

const BUILT_IN: TaxonomySettings = {
  towns: [...CAGAYAN_TOWNS],
  subcategories: {},
};

function load(): Promise<TaxonomySettings> {
  cache ??= getSettings<TaxonomySettings>("taxonomy")
    .then(({ data }) => ({
      towns: data?.towns?.length ? data.towns : BUILT_IN.towns,
      subcategories: data?.subcategories ?? {},
    }))
    .catch(() => {
      cache = null;
      return BUILT_IN;
    });
  return cache;
}

/** Forget the cached lists — after Settings saves new ones. */
export function refreshTaxonomy() {
  cache = null;
}

/**
 * The town list and subcategories to offer in the destination editor: the
 * province's, from Settings, or the built-in towns and no subcategories
 * until anyone has saved them.
 */
export function useTaxonomy(): TaxonomySettings {
  const [taxonomy, setTaxonomy] = useState<TaxonomySettings>(BUILT_IN);
  useEffect(() => {
    let live = true;
    void load().then((t) => live && setTaxonomy(t));
    return () => {
      live = false;
    };
  }, []);
  return taxonomy;
}
