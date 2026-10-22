import { useEffect, useState } from "react";
import { Link, useParams, useSearchParams } from "react-router-dom";
import { Printer, Scan } from "lucide-react";
import logo from "../../../assets/images/EndlessFunCagayan.png";
import { getDestination, imageUrl } from "../lib/destinations";
import { listExhibits } from "../lib/exhibits";
import { imageAspect, VISIT_URL } from "../lib/labels";
import type { ExhibitDraft } from "../types/exhibit";
import {
  LABEL_SIZES,
  labelSizeOf,
  printedPicture,
  qrPath,
  sheetsOf,
  visitUrl,
  type LabelSize,
} from "../types/label";
import "../styles/labels.css";

type Place = { id: string; name: string; town: string };

type PrintLabel = {
  exhibit: ExhibitDraft;
  size: LabelSize;
  url: string;
  aspect: number;
};

type Skipped = { exhibit: ExhibitDraft; reason: string };

type Loaded = { place: Place; labels: PrintLabel[]; skipped: Skipped[] };

/**
 * Lakbayan exhibit labels for a museum, laid out on A4 to print and cut
 * (D-18): four A6 or two A5 to a landscape sheet.
 *
 * Opened from the AR tab, in its own browser tab, for every exhibit or the
 * ones in `?ids=`. It prints what is saved, not what is on the editor's
 * screen — the tab only offers it once the destination has no unsaved
 * changes — so a label can never show a picture its exhibit no longer scans
 * for. Each exhibit's size is read from its marker width (`labelSizeOf`);
 * one measured by hand, for its own placard, gets no Lakbayan label.
 */
export function LabelsPrintPage() {
  const { id = "" } = useParams();
  const [params] = useSearchParams();
  const only = params.get("ids");
  const [state, setState] = useState<Loaded | { error: string } | null>(null);
  const [fontsReady, setFontsReady] = useState(false);

  useEffect(() => {
    let cancelled = false;
    load(id, only?.split(",").filter(Boolean) ?? null)
      .then((loaded) => !cancelled && setState(loaded))
      .catch(
        (err: unknown) =>
          !cancelled &&
          setState({ error: err instanceof Error ? err.message : String(err) }),
      );
    return () => {
      cancelled = true;
    };
  }, [id, only]);

  useEffect(() => {
    // Printing before Barabara arrives would print the wordmark in a
    // fallback face.
    void document.fonts.ready.then(() => setFontsReady(true));
  }, []);

  if (!state) return <div className="boot">Loading labels…</div>;
  if ("error" in state) {
    return (
      <div className="print-page">
        <div className="print-toolbar">
          <div>
            <h1>Labels could not be prepared</h1>
            <p className="hint">{state.error}</p>
          </div>
        </div>
      </div>
    );
  }

  const { place, labels, skipped } = state;
  const sheets = sheetsOf(labels);

  return (
    <div className="print-page">
      <div className="print-toolbar">
        <div>
          <h1>Labels · {place.name}</h1>
          <p className="hint">
            {labels.length === 0
              ? "Nothing to print yet."
              : `${labels.length} label${labels.length === 1 ? "" : "s"} on ${sheets.length} A4 sheet${sheets.length === 1 ? "" : "s"}. `}
            {labels.length > 0 &&
              "Print on A4, landscape, at actual size (100%), with background graphics on — the scanner expects the picture exactly as wide as it is set to."}
          </p>
          {skipped.length > 0 && (
            <ul className="print-skipped">
              {skipped.map(({ exhibit, reason }) => (
                <li key={exhibit.id}>
                  <strong>{exhibit.title || "Untitled exhibit"}</strong>:{" "}
                  {reason}
                </li>
              ))}
            </ul>
          )}
        </div>
        <span className="spacer" />
        <Link className="btn-quiet" to={`/destinations/${place.id}`}>
          Back to the editor
        </Link>
        <button
          className="btn-primary"
          onClick={() => window.print()}
          disabled={labels.length === 0 || !fontsReady}
        >
          <Printer size={16} aria-hidden="true" />
          Print
        </button>
      </div>

      {sheets.map((sheet, i) => (
        <section className="print-sheet" key={i} aria-label={`Sheet ${i + 1}`}>
          {sheet.map((label) => (
            <ExhibitLabel key={label.exhibit.id} label={label} place={place} />
          ))}
        </section>
      ))}
    </div>
  );
}

async function load(id: string, only: string[] | null): Promise<Loaded> {
  const [destination, exhibits] = await Promise.all([
    getDestination(id),
    listExhibits(id),
  ]);
  if (!destination) throw new Error("This destination no longer exists.");
  const place = { id, name: destination.name, town: destination.town };
  const chosen = only ? exhibits.filter((e) => only.includes(e.id)) : exhibits;

  const labels: PrintLabel[] = [];
  const skipped: Skipped[] = [];
  await Promise.all(
    chosen.map(async (exhibit) => {
      if (!exhibit.markerPath) {
        skipped.push({ exhibit, reason: "no marker photo yet." });
        return;
      }
      try {
        const [url, aspect] = await Promise.all([
          imageUrl(exhibit.markerPath),
          imageAspect(exhibit.markerPath),
        ]);
        const size = labelSizeOf(exhibit.markerWidthM, aspect);
        if (size) {
          labels.push({ exhibit, size, url, aspect });
        } else {
          skipped.push({
            exhibit,
            reason:
              "its width was measured for its own placard. Choose A6 or A5 under Lakbayan label in the AR tab to print one of these instead.",
          });
        }
      } catch {
        skipped.push({ exhibit, reason: "its marker photo could not be loaded." });
      }
    }),
  );
  // Back in the exhibits' own order, which the parallel loads lost.
  const order = new Map(chosen.map((e, i) => [e.id, i]));
  labels.sort((a, b) => order.get(a.exhibit.id)! - order.get(b.exhibit.id)!);
  skipped.sort((a, b) => order.get(a.exhibit.id)! - order.get(b.exhibit.id)!);
  return { place, labels, skipped };
}

/** One label, as designed in the pilot's draft (D-18). */
function ExhibitLabel({ label, place }: { label: PrintLabel; place: Place }) {
  const { exhibit, size, url, aspect } = label;
  const picture = printedPicture(aspect, size);
  const qr = qrPath(visitUrl(VISIT_URL, place.id, exhibit.id));
  const box = LABEL_SIZES[size].pictureMm;

  return (
    <article className={`lk-label ${size}`}>
      <header className="lk-band">
        <span className="lk-wordmark">LAKBAYAN</span>
        <span className="lk-cta">
          <Scan aria-hidden="true" />
          Scan to hear its story
        </span>
      </header>
      <div className="lk-body">
        <div
          className="lk-picture-box"
          style={{ width: `${box}mm`, height: `${box}mm` }}
        >
          {/* Printed exactly this wide: it is the marker, and the exhibit's
              width says so. The brackets sit outside it. */}
          <figure
            className="lk-picture"
            style={{
              width: `${picture.widthMm}mm`,
              height: `${picture.heightMm}mm`,
            }}
          >
            <img src={url} alt="" />
            <span className="c tl" />
            <span className="c tr" />
            <span className="c bl" />
            <span className="c br" />
          </figure>
        </div>
        <div className="lk-side">
          <div className="lk-text">
            <h2 className="lk-title">{exhibit.title}</h2>
            {exhibit.description && (
              <p className="lk-line">{exhibit.description}</p>
            )}
          </div>
          <div className="lk-how">
            <ol className="lk-steps">
              <li>Open the Lakbayan app</li>
              <li>Tap Scan an exhibit</li>
              <li>Point at the picture</li>
            </ol>
            <div className="lk-qr-row">
              <svg
                className="lk-qr"
                viewBox={`0 0 ${qr.size} ${qr.size}`}
                shapeRendering="crispEdges"
                role="img"
                aria-label="QR code for this exhibit"
              >
                <rect width={qr.size} height={qr.size} fill="#fff" />
                <path d={qr.d} />
              </svg>
              <p className="lk-qr-note">
                <b>No app?</b> Scan this code with your camera.
              </p>
            </div>
          </div>
        </div>
      </div>
      <footer className="lk-foot">
        <span>
          {place.name}
          {place.town ? ` · ${place.town}` : ""}
        </span>
        <img src={logo} alt="Endless Fun, Cagayan" />
      </footer>
    </article>
  );
}
