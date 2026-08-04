import { useEffect, useState } from "react";
import { collection, getCountFromServer, query, where } from "firebase/firestore";
import { db } from "../lib/firebase";

type Counts = { published: number; draft: number } | null;

/**
 * Admin wireframe screen 2 — Dashboard.
 *
 * CMS-0 ships the counts only; the activity feed and quick actions land with
 * CMS-1, once there is content to act on.
 */
export function DashboardPage() {
  const [counts, setCounts] = useState<Counts>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let cancelled = false;

    async function load() {
      try {
        const destinations = collection(db, "destinations");
        // Aggregation queries, so an empty CMS does not download the whole
        // collection just to show two numbers.
        const [published, draft] = await Promise.all([
          getCountFromServer(query(destinations, where("status", "==", "published"))),
          getCountFromServer(query(destinations, where("status", "==", "draft"))),
        ]);
        if (cancelled) return;
        setCounts({
          published: published.data().count,
          draft: draft.data().count,
        });
      } catch (err) {
        if (!cancelled) {
          setError(err instanceof Error ? err.message : String(err));
        }
      }
    }

    void load();
    return () => {
      cancelled = true;
    };
  }, []);

  return (
    <section className="page">
      <header className="page-head">
        <h1>Dashboard</h1>
        <p className="hint">Content overview for the Province of Cagayan.</p>
      </header>

      {error && (
        <p className="error-note">
          Could not read destinations: {error}. Is the emulator running?
        </p>
      )}

      <div className="stat-row">
        <Stat label="Published" value={counts?.published} tone="ok" />
        <Stat label="Drafts" value={counts?.draft} />
      </div>

      <p className="hint">
        Destination editing arrives in CMS-1 — it is what unblocks the mobile
        app's Phase 2.
      </p>
    </section>
  );
}

function Stat({
  label,
  value,
  tone,
}: {
  label: string;
  value: number | undefined;
  tone?: "ok";
}) {
  return (
    <div className="stat">
      <span className="overline">{label}</span>
      <strong className={tone === "ok" ? "stat-value ok" : "stat-value"}>
        {value ?? "—"}
      </strong>
    </div>
  );
}
