/**
 * What a photo or a recording may be once it leaves the CMS.
 *
 * A phone photo is around 4000 px and 4–10 MB. The app never shows one wider
 * than a phone screen, and pinch-zoom on 2000 px is still sharp, but every
 * byte of it lands in the offline download a tourist pulls over mobile data.
 * So photos are scaled to fit {@link MAX_EDGE} and re-encoded before upload
 * (lib/image.ts), and storage.rules refuses anything over
 * {@link MAX_IMAGE_BYTES} as the backstop.
 */
export const MAX_EDGE = 2000;

/** WebP/JPEG quality. Indistinguishable on a phone, a fifth of the bytes. */
export const QUALITY = 0.82;

/**
 * The most a photo may weigh. Mirrors `storage.rules` — keep the two in step.
 * A shrunk photo is a few hundred KB, so this only ever stops one that
 * skipped the shrinking.
 */
export const MAX_IMAGE_BYTES = 3 * 1024 * 1024;

/** Scale `width` × `height` down to fit `max` on its longer edge. Never up. */
export function fitWithin(
  width: number,
  height: number,
  max = MAX_EDGE,
): { width: number; height: number } {
  const scale = Math.min(1, max / Math.max(width, height));
  return {
    width: Math.max(1, Math.round(width * scale)),
    height: Math.max(1, Math.round(height * scale)),
  };
}

export function extensionFor(type: string): string {
  if (type === "image/webp") return "webp";
  if (type === "image/png") return "png";
  return "jpg";
}

/**
 * Whether to upload the photo as picked rather than the re-encoded copy.
 *
 * Only when it already fits, is a format worth keeping, and is the smaller of
 * the two: re-encoding a photo that was already small can make it bigger, and
 * every pass through the encoder loses a little detail.
 */
export function keepOriginal(
  original: { type: string; size: number; width: number; height: number },
  encodedSize: number,
): boolean {
  return (
    (original.type === "image/jpeg" || original.type === "image/webp") &&
    Math.max(original.width, original.height) <= MAX_EDGE &&
    original.size <= encodedSize
  );
}

/** Narration formats the CMS accepts, and the type each is stored under. */
export const AUDIO_TYPES = {
  mp3: "audio/mpeg",
  m4a: "audio/mp4",
  aac: "audio/aac",
  wav: "audio/wav",
  ogg: "audio/ogg",
} as const;

export type AudioExtension = keyof typeof AUDIO_TYPES;

/** The most a recording may weigh. Mirrors `storage.rules`. */
export const MAX_AUDIO_BYTES = 50 * 1024 * 1024;

export function audioExtension(name: string): AudioExtension | null {
  const ext = name.split(".").pop()?.toLowerCase() ?? "";
  return Object.hasOwn(AUDIO_TYPES, ext) ? (ext as AudioExtension) : null;
}
