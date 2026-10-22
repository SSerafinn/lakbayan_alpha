/**
 * Lakbayan exhibit labels: the printed placard beside an exhibit, whose
 * picture is the exhibit's AR marker (D-18).
 *
 * The label prints the marker photo whole, never cropped, fitted inside a
 * square that depends on the label's size. What the camera matches and what
 * is on the wall are then the same image, and its printed width — which
 * ARCore needs as `markerWidthM` — follows from the size and the photo's
 * shape alone, so nobody measures anything.
 *
 * There is no `labelSize` field: the width is the one fact stored, and the
 * size is read back from it (`labelSizeOf`). A width typed by hand, for an
 * exhibit's own placard, simply matches neither size.
 */
import qrcode from "qrcode-generator";

export type LabelSize = "a6" | "a5";

export const LABEL_SIZES: Record<
  LabelSize,
  {
    name: string;
    /** The label, as cut. */
    widthMm: number;
    heightMm: number;
    /** The square the picture is fitted into. */
    pictureMm: number;
    /** Labels to an A4 sheet, printed landscape. */
    perSheet: number;
    use: string;
  }
> = {
  a6: {
    name: "A6",
    widthMm: 148,
    heightMm: 105,
    pictureMm: 66,
    perSheet: 4,
    use: "Beside a small object or in a case.",
  },
  a5: {
    name: "A5",
    widthMm: 148,
    heightMm: 210,
    pictureMm: 112,
    perSheet: 2,
    use: "For a large object, or one seen from further back.",
  },
};

export const LABEL_SIZE_ORDER: LabelSize[] = ["a6", "a5"];

/**
 * The picture as printed: the whole photo inside the label's square, its
 * long side filling it. `aspect` is width over height; anything unusable is
 * taken as square rather than producing a label with no picture.
 */
export function printedPicture(
  aspect: number,
  size: LabelSize,
): { widthMm: number; heightMm: number } {
  const box = LABEL_SIZES[size].pictureMm;
  const a = Number.isFinite(aspect) && aspect > 0 ? aspect : 1;
  return a >= 1
    ? { widthMm: box, heightMm: round1(box / a) }
    : { widthMm: round1(box * a), heightMm: box };
}

/** The `markerWidthM` a label of `size` gives this photo, to the millimetre. */
export function labelMarkerWidthM(aspect: number, size: LabelSize): number {
  return Math.round(printedPicture(aspect, size).widthMm) / 1000;
}

/**
 * Which label a stored width belongs to, or null for a width measured by
 * hand. Within a millimetre, which is the precision the width is kept to.
 */
export function labelSizeOf(
  markerWidthM: number,
  aspect: number,
): LabelSize | null {
  return (
    LABEL_SIZE_ORDER.find(
      (size) =>
        Math.abs(markerWidthM - labelMarkerWidthM(aspect, size)) < 0.0011,
    ) ?? null
  );
}

/**
 * Where a label's QR code goes: the exhibit on the visitor site, which opens
 * the app when it is installed. `base` has no trailing slash.
 */
export function visitUrl(
  base: string,
  destinationId: string,
  exhibitId: string,
): string {
  return `${base.replace(/\/+$/, "")}/e/${encodeURIComponent(destinationId)}/${encodeURIComponent(exhibitId)}`;
}

/**
 * A QR code as one SVG path in module units, with a two-module quiet zone.
 * Error correction M: a label behind glass, scuffed at a corner, still reads.
 */
export function qrPath(text: string): { size: number; d: string } {
  const qr = qrcode(0, "M");
  qr.addData(text);
  qr.make();
  const n = qr.getModuleCount();
  const quiet = 2;
  let d = "";
  for (let row = 0; row < n; row++) {
    for (let col = 0; col < n; col++) {
      if (qr.isDark(row, col)) d += `M${col + quiet} ${row + quiet}h1v1h-1z`;
    }
  }
  return { size: n + quiet * 2, d };
}

/**
 * Labels onto A4 sheets: each sheet holds one size, filled in the order
 * given, A6 sheets before A5.
 */
export function sheetsOf<T extends { size: LabelSize }>(labels: T[]): T[][] {
  const sheets: T[][] = [];
  for (const size of LABEL_SIZE_ORDER) {
    const these = labels.filter((l) => l.size === size);
    const per = LABEL_SIZES[size].perSheet;
    for (let i = 0; i < these.length; i += per) {
      sheets.push(these.slice(i, i + per));
    }
  }
  return sheets;
}

function round1(mm: number): number {
  return Math.round(mm * 10) / 10;
}
