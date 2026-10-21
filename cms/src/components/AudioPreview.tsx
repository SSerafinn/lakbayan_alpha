import { useEffect, useState } from "react";
import { audioDownloadUrl } from "../lib/segments";

/**
 * Play back what was uploaded.
 *
 * The document stores a Storage path, so this resolves a download URL the same
 * way `ImageThumb` does. Worth the round trip: an editor who cannot hear the
 * file has no way to catch the wrong take, and the app is where they would
 * find out.
 *
 * Shared by the audio guide and the AR exhibits, whose narration is the same
 * kind of file in the same folder.
 */
export function AudioPreview({ path }: { path: string }) {
  const [url, setUrl] = useState<string | null>(null);
  const [failed, setFailed] = useState(false);

  useEffect(() => {
    let cancelled = false;
    setUrl(null);
    setFailed(false);
    audioDownloadUrl(path)
      .then((u) => !cancelled && setUrl(u))
      .catch(() => !cancelled && setFailed(true));
    return () => {
      cancelled = true;
    };
  }, [path]);

  if (failed) return <p className="hint">Recording unavailable.</p>;
  if (!url) return <p className="hint">Loading the recording…</p>;
  return <audio className="segment-player" controls src={url} />;
}
