import { useEffect, useState } from "react";
import { imageUrl } from "./destinations";

/**
 * The visitor site a label's QR code opens: the exhibit's story for a phone
 * without the app, and the app itself where it is installed.
 *
 * Its own Hosting site, not the CMS's: the CMS is the project's default site
 * and is for administrators. Set `VITE_VISIT_URL` once that site exists; the
 * default is only the name it is meant to have. A label printed today keeps
 * whatever address it was printed with.
 */
export const VISIT_URL: string =
  import.meta.env.VITE_VISIT_URL ?? "https://lakbayan-visit.web.app";

const aspects = new Map<string, Promise<number>>();

/**
 * A Storage image's width over its height, read from the image itself.
 *
 * Asked once per path: a marker's path changes with every upload, so what
 * is remembered under one never goes stale.
 */
export function imageAspect(path: string): Promise<number> {
  let known = aspects.get(path);
  if (!known) {
    known = imageUrl(path).then(
      (url) =>
        new Promise<number>((resolve, reject) => {
          const img = new Image();
          img.onload = () =>
            img.naturalHeight > 0
              ? resolve(img.naturalWidth / img.naturalHeight)
              : reject(new Error("The image has no height."));
          img.onerror = () => reject(new Error("The image did not load."));
          img.src = url;
        }),
    );
    // A failure is not remembered: the next ask tries again.
    known.catch(() => aspects.delete(path));
    aspects.set(path, known);
  }
  return known;
}

/** [imageAspect] for a component: null until known, and while it fails. */
export function useImageAspect(path: string | undefined): number | null {
  const [state, setState] = useState<{ path: string; aspect: number } | null>(
    null,
  );
  useEffect(() => {
    if (!path) return;
    let cancelled = false;
    imageAspect(path)
      .then((aspect) => !cancelled && setState({ path, aspect }))
      .catch(() => {});
    return () => {
      cancelled = true;
    };
  }, [path]);
  return state && state.path === path ? state.aspect : null;
}
