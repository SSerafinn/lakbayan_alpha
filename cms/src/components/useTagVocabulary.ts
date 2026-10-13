import { useEffect, useState } from "react";
import { listDestinations } from "../lib/destinations";
import { tagUsage } from "../types/settings";

// Every tag in use, read once per page load: the editor's tag field suggests
// from it, so "cave" offers the "caves" that is already there.
let cache: Promise<string[]> | null = null;

function load(): Promise<string[]> {
  cache ??= listDestinations()
    .then((all) => tagUsage(all).map((u) => u.tag))
    .catch((err) => {
      // Suggestions are a convenience: the field still works without them,
      // but say why they are missing rather than failing silently.
      console.warn("Tag suggestions unavailable:", err);
      cache = null;
      return [];
    });
  return cache;
}

/** Forget the cached tags — after a rename or merge in Settings. */
export function refreshTagVocabulary() {
  cache = null;
}

/** Tags already used on any destination, most used first. */
export function useTagVocabulary(): string[] {
  const [tags, setTags] = useState<string[]>([]);
  useEffect(() => {
    let live = true;
    void load().then((t) => live && setTags(t));
    return () => {
      live = false;
    };
  }, []);
  return tags;
}
