import { useEffect, useMemo, useState } from "react";
import { Package, RefreshCw } from "lucide-react";
import { Alert, FoldingAlert } from "../components/Alert";
import { PageHeader } from "../components/PageHeader";
import { formatDate } from "../types/format";
import { useToast } from "../components/toast-context";
import { listDestinations } from "../lib/destinations";
import { generateBundle, listBundles } from "../lib/bundles";
import { callableMessage } from "../lib/users";
import { formatBytes, type OfflineBundle } from "../types/bundle";
import type { Destination } from "../types/destination";

/**
 * Admin wireframe screen 7 — Offline bundles.
 *
 * One row per town that has publishable content, whether or not a bundle has
 * been built for it. Listing only existing bundles would hide the towns that
 * need one, which is the question this screen exists to answer.
 */
type Row = {
  town: string;
  eligible: number;
  bundle?: OfflineBundle;
  /** Set after a dry run: the version the content would produce now. */
  wouldBe?: string;
  missing?: string[];
};

export function BundlesPage() {
  const toast = useToast();
  const [destinations, setDestinations] = useState<Destination[] | null>(null);
  const [bundles, setBundles] = useState<Map<string, OfflineBundle>>(new Map());
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState<string | null>(null);
  const [checked, setChecked] = useState<Map<string, Row>>(new Map());

  async function reload() {
    try {
      const [d, b] = await Promise.all([listDestinations(), listBundles()]);
      setDestinations(d);
      setBundles(b);
      setError(null);
    } catch (err) {
      setError(err instanceof Error ? err.message : String(err));
    }
  }

  useEffect(() => {
    void reload();
  }, []);

  const rows = useMemo<Row[]>(() => {
    const counts = new Map<string, number>();
    for (const d of destinations ?? []) {
      // The same filter the function and the tile extractor apply, so all
      // three agree on what a town's bundle contains.
      if (d.status !== "published" || d.offlineEligible === false) continue;
      const town = d.town.trim();
      if (!town) continue;
      counts.set(town, (counts.get(town) ?? 0) + 1);
    }
    return [...counts.entries()]
      .sort(([a], [b]) => a.localeCompare(b))
      .map(([town, eligible]) => {
        const bundle = [...bundles.values()].find((b) => b.name === town);
        return { town, eligible, bundle, ...checked.get(town) };
      });
  }, [destinations, bundles, checked]);

  async function run(town: string, dryRun: boolean) {
    setBusy(town);
    try {
      const manifest = await generateBundle(town, { dryRun });
      if (dryRun) {
        setChecked((prev) =>
          new Map(prev).set(town, {
            town,
            eligible: 0,
            wouldBe: manifest.version,
            missing: manifest.missing,
          }),
        );
        toast.success(
          `Checked ${town}`,
          manifest.missing.length === 0
            ? "Everything it needs is in Storage."
            : `${manifest.missing.length} file(s) still missing.`,
        );
      } else {
        setChecked((prev) => {
          const next = new Map(prev);
          next.delete(town);
          return next;
        });
        await reload();
        toast.success(
          `Built ${town}`,
          `${manifest.status} · ${formatBytes(manifest.size)} · version ${manifest.version}`,
        );
      }
    } catch (err) {
      toast.error(
        dryRun ? "Could not check" : "Could not build",
        callableMessage(err),
      );
    } finally {
      setBusy(null);
    }
  }

  return (
    <section className="page">
      <PageHeader
        title="Offline bundles"
        meta={
          destinations === null
            ? "Loading…"
            : `${rows.length} town${rows.length === 1 ? "" : "s"} with publishable content`
        }
      />

      <FoldingAlert
        id="bundles-manifest"
        title="A bundle is a manifest, not an archive"
      >
        Building one records which destinations a town contains, how large the
        download is, and a version. The phone reads it and fetches the files
        itself. A bundle is <strong>ready</strong> only when every photo,
        recording and the map pack are in Storage — the map pack is rendered
        separately with <code>tools/tiles</code> and uploaded to{" "}
        <code>tiles/&lt;townId&gt;/pack.pmtiles</code>.
      </FoldingAlert>

      {error && (
        <Alert variant="destructive" title="Could not load bundles">
          {error}. Is the emulator running, and do you still have the admin
          claim?
        </Alert>
      )}

      {destinations !== null && rows.length === 0 ? (
        <div className="empty">
          <p>
            No town has published, offline-eligible destinations yet. Publish
            something first.
          </p>
        </div>
      ) : (
        <table className="data">
          <thead>
            <tr>
              <th>Town</th>
              <th>Places</th>
              <th>Status</th>
              <th>Size</th>
              <th>Version</th>
              <th>Built</th>
              <th />
            </tr>
          </thead>
          <tbody>
            {rows.map((row) => {
              const isBusy = busy === row.town;
              // A dry run that returns a different version than the stored one
              // is the definition of stale: the content moved on since.
              const stale =
                row.wouldBe !== undefined &&
                row.bundle !== undefined &&
                row.wouldBe !== row.bundle.version;

              return (
                <tr key={row.town}>
                  <td>
                    <span className="row">
                      <Package size={14} aria-hidden="true" />
                      {row.town}
                    </span>
                  </td>
                  <td>{row.eligible}</td>
                  <td>
                    {row.bundle === undefined ? (
                      <span className="badge draft">Never built</span>
                    ) : stale ? (
                      <span className="badge warn">Stale</span>
                    ) : row.bundle.status === "ready" ? (
                      <span className="badge ok">Ready</span>
                    ) : (
                      <span className="badge warn">Pending</span>
                    )}
                  </td>
                  <td>
                    {row.bundle ? formatBytes(row.bundle.size) : <span className="hint">—</span>}
                  </td>
                  <td className="hint">
                    <code>{row.bundle?.version ?? "—"}</code>
                    {stale && row.wouldBe && (
                      <>
                        {" → "}
                        <code>{row.wouldBe}</code>
                      </>
                    )}
                  </td>
                  <td className="hint">
                    {formatDate(row.bundle?.generatedAt)}
                  </td>
                  <td className="row">
                    <button
                      className="btn-quiet sm"
                      disabled={isBusy}
                      onClick={() => void run(row.town, true)}
                      title="Work out what a rebuild would produce, without writing it"
                    >
                      <RefreshCw size={12} aria-hidden="true" /> Check
                    </button>
                    <button
                      className="btn-secondary sm"
                      disabled={isBusy}
                      onClick={() => void run(row.town, false)}
                    >
                      {row.bundle ? "Rebuild" : "Build"}
                    </button>
                  </td>
                </tr>
              );
            })}
          </tbody>
        </table>
      )}

      {rows.some((r) => r.missing && r.missing.length > 0) && (
        <Alert variant="destructive" title="Some files are not in Storage yet">
          <ul>
            {rows
              .filter((r) => r.missing && r.missing.length > 0)
              .map((r) => (
                <li key={r.town}>
                  <strong>{r.town}</strong>: {r.missing!.join(", ")}
                </li>
              ))}
          </ul>
          A bundle stays <strong>pending</strong> until these exist. The phone
          would otherwise download it, find no map, and be unable to tell that
          from a failed download.
        </Alert>
      )}
    </section>
  );
}
