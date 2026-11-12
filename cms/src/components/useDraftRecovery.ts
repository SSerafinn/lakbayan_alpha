import { useCallback, useEffect, useRef, useState } from "react";
import type { Destination } from "../types/destination";
import type { ExhibitDraft } from "../types/exhibit";
import type { SegmentDraft } from "../types/segment";
import {
  differsFrom,
  makeRecovery,
  readRecovery,
  type Recovery,
} from "../types/recovery";

type Parts = {
  draft: Omit<Destination, "id">;
  segments: SegmentDraft[];
  exhibits: ExhibitDraft[];
};

/** How long typing pauses before the copy is rewritten. */
const WRITE_DELAY_MS = 500;

function storage(): Storage | null {
  try {
    return window.localStorage;
  } catch {
    return null;
  }
}

/**
 * Keeps a copy of an editor's unsaved edits in this browser, and offers it
 * back when the editor opens on the same place with it still there.
 *
 * - `key` is null until both the admin and the place are known.
 * - `loaded` is what was loaded from Firestore, null until all of it is
 *   (the audio guide and exhibits land after the document).
 * - The copy is rewritten while there are edits and removed once there are
 *   none, which is what a save, a Discard and loading theirs all come to.
 *
 * While a copy is on offer nothing is written over it: the page's own state
 * is the loaded version, and saving that would lose what is being offered.
 */
export function useDraftRecovery({
  key,
  loaded,
  current,
  dirty,
  basedOn,
}: {
  key: string | null;
  loaded: Parts | null;
  current: Parts | null;
  dirty: boolean;
  /** The version the edits on screen started from, read when the copy is written. */
  basedOn: () => number;
}): { offer: Recovery | null; dismiss: () => void } {
  const [offer, setOffer] = useState<Recovery | null>(null);
  /** The key whose stored copy has been looked at; writing waits for it. */
  const [checked, setChecked] = useState<string | null>(null);
  const previous = useRef<string | null>(null);
  const basedOnRef = useRef(basedOn);
  useEffect(() => {
    basedOnRef.current = basedOn;
  });

  // Look once per place, as soon as everything is loaded.
  useEffect(() => {
    if (!key || !loaded || checked === key) return;
    const store = storage();
    const found = readRecovery(store?.getItem(key) ?? null, Date.now());
    if (found && differsFrom(found, loaded)) {
      setOffer(found);
    } else {
      // Expired, unreadable, or nothing the saved version lacks.
      store?.removeItem(key);
      setOffer(null);
    }
    setChecked(key);
  }, [key, loaded, checked]);

  // A new place's copy is kept under "new" until its first save gives it an
  // id. The key moving on means that save landed, so the old copy goes.
  useEffect(() => {
    if (previous.current && previous.current !== key) {
      storage()?.removeItem(previous.current);
    }
    previous.current = key;
  }, [key]);

  // Write while there are edits; remove once there are none.
  useEffect(() => {
    if (!key || checked !== key || offer || !current) return;
    const store = storage();
    if (!dirty) {
      store?.removeItem(key);
      return;
    }
    const timer = window.setTimeout(() => {
      try {
        store?.setItem(
          key,
          JSON.stringify(makeRecovery(current, basedOnRef.current(), Date.now())),
        );
      } catch {
        // Storage full or blocked: the edits are still on screen, and the
        // usual guards still ask before they are lost.
      }
    }, WRITE_DELAY_MS);
    return () => window.clearTimeout(timer);
  }, [key, checked, offer, current, dirty]);

  const dismiss = useCallback(() => {
    if (key) storage()?.removeItem(key);
    setOffer(null);
  }, [key]);

  return { offer, dismiss };
}
