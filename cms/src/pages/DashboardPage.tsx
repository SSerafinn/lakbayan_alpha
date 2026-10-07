import { useEffect, useMemo, useState } from "react";
import { Link } from "react-router-dom";
import {
  CircleCheck,
  MapPin,
  Plus,
  Route,
  TriangleAlert,
  UsersRound,
  type LucideIcon,
} from "lucide-react";
import { Alert } from "../components/Alert";
import { useAuth } from "../auth/auth-context";
import { listBundles } from "../lib/bundles";
import { listDestinations } from "../lib/destinations";
import { useEmulators } from "../lib/firebase";
import { listGuides } from "../lib/guides";
import { listTours } from "../lib/tours";
import { countUsers, listAdmins } from "../lib/users";
import type { OfflineBundle } from "../types/bundle";
import {
  bundlesNeedingWork,
  draftsNeedingWork,
  recentActivity,
  relativeTime,
  toursNeedingWork,
  type Activity,
  type ActivityKind,
  type AttentionItem,
} from "../types/dashboard";
import type { Destination } from "../types/destination";
import type { Guide } from "../types/guide";
import type { Tour } from "../types/tour";

type Data = {
  destinations: Destination[];
  tours: Tour[];
  guides: Guide[];
  bundles: Map<string, OfflineBundle>;
  users: number;
};

/** How many items a group shows before handing off to its own screen. */
const GROUP_LIMIT = 5;

const KIND: Record<ActivityKind, { label: string; icon: LucideIcon }> = {
  destination: { label: "destination", icon: MapPin },
  tour: { label: "tour", icon: Route },
  guide: { label: "guide", icon: UsersRound },
};

/**
 * Admin wireframe screen 2 — Dashboard.
 *
 * Answers "what should I do next?" before "how much is there?": the counts are
 * a glance, the attention list is the work. Everything on it links to the
 * exact place the fix happens.
 *
 * Reads whole collections rather than aggregation counts, because the
 * attention list needs the documents anyway — and counting from the same read
 * means the numbers and the lists can never disagree. The destination list
 * screen already reads the same collection, so this is no new cost per
 * document. App users are the exception: only the number is shown, and that
 * collection grows with every visitor, so it stays a count.
 */
export function DashboardPage() {
  const { user } = useAuth();
  const [data, setData] = useState<Data | null>(null);
  const [error, setError] = useState<string | null>(null);
  /** uid → a readable name, for "by …" on the activity feed. */
  const [names, setNames] = useState<Map<string, string>>(new Map());

  useEffect(() => {
    let cancelled = false;

    async function load() {
      try {
        const [destinations, tours, guides, bundles, users] =
          await Promise.all([
            listDestinations(),
            listTours(),
            listGuides(),
            listBundles(),
            countUsers(),
          ]);
        if (!cancelled) setData({ destinations, tours, guides, bundles, users });
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

  const activity = useMemo(() => (data ? recentActivity(data) : []), [data]);

  const groups = useMemo(
    () =>
      data
        ? [
            {
              title: "Drafts",
              items: draftsNeedingWork(data.destinations),
              more: "/destinations",
            },
            {
              title: "Offline bundles",
              items: bundlesNeedingWork(data.destinations, data.bundles),
              more: "/bundles",
            },
            {
              title: "Tours",
              items: toursNeedingWork(data.tours, data.destinations),
              more: "/tours",
            },
          ].filter((g) => g.items.length > 0)
        : [],
    [data],
  );

  // Names for other admins' edits. Only fetched when there is someone other
  // than the signed-in user to name, and a failure is silent — the feed reads
  // fine without "by …", and listAdmins is a Cloud Function that may be cold.
  useEffect(() => {
    const others = activity.some((a) => a.by && a.by !== user?.uid);
    if (!others) return;
    let cancelled = false;
    listAdmins()
      .then((admins) => {
        if (cancelled) return;
        setNames(
          new Map(
            admins.map((a) => [a.uid, a.displayName || a.email || "an admin"]),
          ),
        );
      })
      .catch(() => {});
    return () => {
      cancelled = true;
    };
  }, [activity, user?.uid]);

  const published =
    data?.destinations.filter((d) => d.status === "published").length;
  const drafts = data?.destinations.filter((d) => d.status === "draft").length;
  const now = Date.now();

  function who(a: Activity): string | null {
    if (!a.by) return null;
    if (a.by === user?.uid) return "you";
    // A revoked admin is no longer in the list. Saying nothing is more honest
    // than a uid nobody can read.
    return names.get(a.by) ?? null;
  }

  return (
    <section className="page">
      <header className="page-head">
        <h1>Dashboard</h1>
        <p className="hint">Content overview for the Province of Cagayan.</p>
      </header>

      {error && (
        <Alert variant="destructive" title="Could not load the dashboard">
          {error}.{" "}
          {useEmulators
            ? "Is the emulator running?"
            : "Check your connection, and that you still have the admin claim."}
        </Alert>
      )}

      <div className="stat-row">
        <Stat label="Published" value={published} tone="ok" />
        <Stat label="Drafts" value={drafts} />
        <Stat label="Tours" value={data?.tours.length} />
        <Stat label="Local guides" value={data?.guides.length} />
        <Stat label="App users" value={data?.users} />
      </div>

      <div className="quick-actions">
        <Link className="btn-primary" to="/destinations/new">
          <Plus size={18} aria-hidden="true" />
          New destination
        </Link>
        <Link className="btn-secondary" to="/tours?new">
          New tour
        </Link>
        <Link className="btn-secondary" to="/guides?new">
          Add a guide
        </Link>
      </div>

      <div className="dash-grid">
        <section className="panel" aria-labelledby="attention-title">
          <header>
            <h2 id="attention-title">Needs attention</h2>
          </header>
          {data === null ? (
            error ? null : <Loading />
          ) : groups.length === 0 ? (
            <p className="panel-empty">
              <CircleCheck size={18} aria-hidden="true" className="icon-ok" />
              Nothing needs attention. Every draft, bundle and tour is in order.
            </p>
          ) : (
            groups.map((g) => (
              <AttentionGroup key={g.title} {...g} />
            ))
          )}
        </section>

        <section className="panel" aria-labelledby="activity-title">
          <header>
            <h2 id="activity-title">Recent activity</h2>
          </header>
          {data === null ? (
            error ? null : <Loading />
          ) : activity.length === 0 ? (
            <p className="panel-empty">
              No edits yet. Start with a destination — tours and offline
              bundles are built from them.
            </p>
          ) : (
            <ul className="activity">
              {activity.map((a) => {
                const { label, icon: Icon } = KIND[a.kind];
                const by = who(a);
                return (
                  <li key={`${a.kind}:${a.id}`}>
                    <Icon size={18} aria-hidden="true" className="activity-icon" />
                    <div className="activity-body">
                      <Link to={a.href}>{a.name}</Link>
                      <span className="hint">
                        {a.verb} {label} · {relativeTime(a.at, now)}
                        {by && ` · by ${by}`}
                      </span>
                    </div>
                    {a.status && (
                      <span
                        className={
                          a.status === "published" ? "badge ok" : "badge draft"
                        }
                      >
                        {a.status === "published" ? "Published" : "Draft"}
                      </span>
                    )}
                  </li>
                );
              })}
            </ul>
          )}
          {activity.length > 0 && (
            <p className="hint">
              Deletions are not listed, and publishing shows as an edit — the
              badge says which way it went.
            </p>
          )}
        </section>
      </div>
    </section>
  );
}

function AttentionGroup({
  title,
  items,
  more,
}: {
  title: string;
  items: AttentionItem[];
  more: string;
}) {
  const hidden = items.length - GROUP_LIMIT;
  return (
    <div className="attention-group">
      <h3 className="overline">
        {title} · {items.length}
      </h3>
      <ul className="attention">
        {items.slice(0, GROUP_LIMIT).map((i) => (
          <li key={i.key}>
            <Link to={i.href}>
              {i.ready ? (
                <CircleCheck size={18} aria-hidden="true" className="icon-ok" />
              ) : (
                <TriangleAlert
                  size={18}
                  aria-hidden="true"
                  className="icon-warn"
                />
              )}
              <span className="attention-body">
                <strong>{i.title}</strong>
                <span className="hint">{i.detail}</span>
              </span>
            </Link>
          </li>
        ))}
      </ul>
      {hidden > 0 && (
        <Link className="btn-quiet sm" to={more}>
          {hidden} more in {title.toLowerCase()}
        </Link>
      )}
    </div>
  );
}

function Loading() {
  return (
    <div className="panel-loading" aria-busy="true" aria-label="Loading">
      <div className="skeleton" />
      <div className="skeleton" />
      <div className="skeleton" />
    </div>
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
