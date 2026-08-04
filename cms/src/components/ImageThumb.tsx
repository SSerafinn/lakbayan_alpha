import { useEffect, useState } from "react";
import { imageUrl } from "../lib/destinations";

/**
 * Renders a Storage **path** as an image.
 *
 * The document stores paths, not download URLs (see docs/DATA_MODEL.md), so
 * every thumbnail needs a round trip to resolve one. Failures render as a
 * placeholder rather than a broken image: against the emulator this usually
 * just means the file was never uploaded.
 */
export function ImageThumb({ path }: { path: string }) {
  const [url, setUrl] = useState<string | null>(null);
  const [failed, setFailed] = useState(false);

  useEffect(() => {
    let cancelled = false;
    imageUrl(path)
      .then((u) => !cancelled && setUrl(u))
      .catch(() => !cancelled && setFailed(true));
    return () => {
      cancelled = true;
    };
  }, [path]);

  if (failed) return <div className="thumb missing">unavailable</div>;
  if (!url) return <div className="thumb skeleton" />;
  return <img className="thumb" src={url} alt="" loading="lazy" />;
}
