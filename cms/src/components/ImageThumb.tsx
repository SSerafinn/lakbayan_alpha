import { useImageUrl } from "./useImageUrl";

/**
 * Renders a Storage **path** as an image.
 *
 * The document stores paths, not download URLs (see docs/DATA_MODEL.md), so
 * every thumbnail needs a round trip to resolve one. Failures render as a
 * placeholder rather than a broken image: against the emulator this usually
 * just means the file was never uploaded.
 */
export function ImageThumb({
  path,
  className,
}: {
  path: string;
  /** Added to `thumb` — `row-thumb` for the small one in a table row. */
  className?: string;
}) {
  const cls = className ? `thumb ${className}` : "thumb";
  const url = useImageUrl(path);

  if (url === "failed") return <div className={`${cls} missing`}>unavailable</div>;
  if (!url) return <div className={`${cls} skeleton`} />;
  return <img className={cls} src={url} alt="" loading="lazy" />;
}
