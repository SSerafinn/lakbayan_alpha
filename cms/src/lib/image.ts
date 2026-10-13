import {
  extensionFor,
  fitWithin,
  keepOriginal,
  MAX_IMAGE_BYTES,
  QUALITY,
} from "../types/media";
import { formatBytes } from "../types/bundle";

/** A photo the CMS will not upload, with a message that says why. */
export class ImageRejectedError extends Error {}

/**
 * Make a photo fit for the app: scaled to fit `MAX_EDGE` and re-encoded as
 * WebP, or JPEG where the browser cannot write WebP. The original goes up
 * instead only where it already fits and is the smaller of the two (see
 * `keepOriginal`).
 *
 * Re-encoding also drops the camera's metadata, its location included, and
 * bakes in the rotation a phone records as a flag rather than in the pixels.
 */
export async function shrinkImage(file: File): Promise<File> {
  let bitmap: ImageBitmap;
  try {
    bitmap = await createImageBitmap(file, { imageOrientation: "from-image" });
  } catch {
    // Most often an iPhone's HEIC, which no browser here can open — and which
    // the app could not draw either.
    throw new ImageRejectedError(
      `${file.name} could not be opened. Save it as a JPEG or PNG and try again.`,
    );
  }

  try {
    const { width, height } = fitWithin(bitmap.width, bitmap.height);
    const canvas = document.createElement("canvas");
    canvas.width = width;
    canvas.height = height;
    const ctx = canvas.getContext("2d");
    if (!ctx) throw new ImageRejectedError("This browser cannot resize photos.");
    ctx.imageSmoothingQuality = "high";
    ctx.drawImage(bitmap, 0, 0, width, height);

    let blob = await encode(canvas, "image/webp");
    if (blob?.type !== "image/webp") {
      // Safari cannot write WebP, and says so by quietly returning a PNG.
      // JPEG has no transparency, so fill behind the photo first, or a
      // transparent edge comes out black.
      ctx.globalCompositeOperation = "destination-over";
      ctx.fillStyle = "#fff";
      ctx.fillRect(0, 0, width, height);
      blob = await encode(canvas, "image/jpeg");
    }
    if (!blob) throw new ImageRejectedError(`${file.name} could not be resized.`);

    const shrunk = keepOriginal(
      { type: file.type, size: file.size, width: bitmap.width, height: bitmap.height },
      blob.size,
    )
      ? file
      : new File([blob], `${stem(file.name)}.${extensionFor(blob.type)}`, {
          type: blob.type,
        });

    // Storage would refuse it anyway; this says why in words. (The type
    // needs no check: both branches above are a JPEG or a WebP.)
    if (shrunk.size > MAX_IMAGE_BYTES) {
      throw new ImageRejectedError(
        `${file.name} is still ${formatBytes(shrunk.size)} after resizing, over the ${formatBytes(MAX_IMAGE_BYTES)} limit.`,
      );
    }
    return shrunk;
  } finally {
    bitmap.close();
  }
}

function encode(canvas: HTMLCanvasElement, type: string): Promise<Blob | null> {
  return new Promise((resolve) => canvas.toBlob(resolve, type, QUALITY));
}

function stem(name: string): string {
  return name.replace(/\.[^.]*$/, "") || "photo";
}
