import { useEffect, useState } from "react";
import { imageUrl } from "../lib/destinations";

/**
 * A Storage **path** resolved to a URL: null while it loads, "failed" when it
 * cannot be (against the emulator, usually a file never uploaded).
 */
export function useImageUrl(path: string | undefined): string | null | "failed" {
  const [url, setUrl] = useState<string | null | "failed">(null);

  useEffect(() => {
    setUrl(null);
    if (!path) return;
    let cancelled = false;
    imageUrl(path)
      .then((u) => !cancelled && setUrl(u))
      .catch(() => !cancelled && setUrl("failed"));
    return () => {
      cancelled = true;
    };
  }, [path]);

  return url;
}

// Its own module, not ImageThumb.tsx: Fast Refresh only handles a module
// that exports components alone.
