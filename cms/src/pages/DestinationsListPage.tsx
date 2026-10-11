import { useEffect, useMemo, useState } from "react";
import { Link, useNavigate } from "react-router-dom";
import { listDestinations, setStatus } from "../lib/destinations";
import { Alert } from "../components/Alert";
import { PageHeader } from "../components/PageHeader";
import { ImageThumb } from "../components/ImageThumb";
import { relativeTime } from "../types/dashboard";
import { Plus } from "lucide-react";
import {
  CATEGORIES,
  CATEGORY_LABELS,
  type Category,
  type Destination,
  type Status,
} from "../types/destination";

/**
 * Saved views across the top of the table, after Polaris's index pages.
 *
 * They replace the status dropdown: "what is still a draft?" and "what has
 * no photo?" are the two questions this screen gets asked most, and a view
 * answers each with one click and a count. "Needs a photo" is the most common
 * reason a draft cannot be published.
 */
type View = "all" | "published" | "draft" | "no-photo";

const VIEWS: { id: View; label: string; test: (d: Destination) => boolean }[] =
  [
    { id: "all", label: "All", test: () => true },
    {
      id: "published",
      label: "Published",
      test: (d) => d.status === "published",
    },
    { id: "draft", label: "Drafts", test: (d) => d.status === "draft" },
    {
      id: "no-photo",
      label: "Needs a photo",
      test: (d) => d.images.length === 0,
    },
  ];

/**
 * Admin wireframe screen 3 — Destinations list.
 *
 * The wireframe calls this the shared list pattern for Tours, Guides, AR
 * Content and Users: search, then filters, then bulk actions once rows are
 * selected, sorted by last-updated descending. Keep that shape when the later
 * screens reuse it.
 */
export function DestinationsListPage() {
  const navigate = useNavigate();
  const [rows, setRows] = useState<Destination[] | null>(null);
  const [error, setError] = useState<string | null>(null);

  const [search, setSearch] = useState("");
  const [town, setTown] = useState("all");
  const [category, setCategory] = useState<Category | "all">("all");
  const [view, setView] = useState<View>("all");
  const [selected, setSelected] = useState<Set<string>>(new Set());
  const [busy, setBusy] = useState(false);

  async function reload() {
    try {
      setRows(await listDestinations());
      setError(null);
    } catch (err) {
      setError(err instanceof Error ? err.message : String(err));
    }
  }

  useEffect(() => {
    void reload();
  }, []);

  // Towns come from the data rather than a fixed list: Cagayan has 28
  // municipalities and the content team should not need a code change to use
  // one. Settings -> Taxonomy takes this over in CMS-4.
  const towns = useMemo(
    () => [...new Set((rows ?? []).map((r) => r.town).filter(Boolean))].sort(),
    [rows],
  );

  const filtered = useMemo(() => {
    const q = search.trim().toLowerCase();
    return (rows ?? []).filter(
      (r) =>
        (!q ||
          r.name.toLowerCase().includes(q) ||
          r.town.toLowerCase().includes(q)) &&
        (town === "all" || r.town === town) &&
        (category === "all" || r.category === category) &&
        VIEWS.find((v) => v.id === view)!.test(r),
    );
  }, [rows, search, town, category, view]);

  // The view is not a filter to clear: it is which list you are looking at.
  const hasFilters = search.trim() !== "" || town !== "all" || category !== "all";

  function clearFilters() {
    setSearch("");
    setTown("all");
    setCategory("all");
  }

  function toggle(id: string) {
    setSelected((prev) => {
      const next = new Set(prev);
      if (next.has(id)) next.delete(id);
      else next.add(id);
      return next;
    });
  }

  async function bulkSetStatus(next: Status) {
    setBusy(true);
    try {
      await Promise.all([...selected].map((id) => setStatus(id, next)));
      setSelected(new Set());
      await reload();
    } finally {
      setBusy(false);
    }
  }

  const counts = rows
    ? `${rows.length} place${rows.length === 1 ? "" : "s"} in ${towns.length} town${towns.length === 1 ? "" : "s"} · ${rows.filter((r) => r.status === "published").length} published, ${rows.filter((r) => r.status === "draft").length} draft`
    : "Loading…";
  const now = Date.now();

  return (
    <section className="page">
      <PageHeader
        title="Destinations"
        meta={counts}
        actions={
          <button
            className="btn-primary"
            onClick={() => navigate("/destinations/new")}
          >
            <Plus size={18} aria-hidden="true" />
            New destination
          </button>
        }
      />

      {error && (
        <Alert variant="destructive" title="Could not load destinations">
          {error}. Is the emulator running, and do you still have the admin
          claim?
        </Alert>
      )}

      <nav className="tabs views" aria-label="Views">
        {VIEWS.map((v) => (
          <button
            key={v.id}
            className={view === v.id ? "tab on" : "tab"}
            aria-pressed={view === v.id}
            onClick={() => setView(v.id)}
          >
            {v.label}
            {rows && (
              <span className="tab-count">{rows.filter(v.test).length}</span>
            )}
          </button>
        ))}
      </nav>

      <div className="toolbar">
        <input
          className="search"
          placeholder="Search by name or town"
          value={search}
          onChange={(e) => setSearch(e.target.value)}
        />
        <select value={town} onChange={(e) => setTown(e.target.value)}>
          <option value="all">Town: All</option>
          {towns.map((t) => (
            <option key={t} value={t}>
              {t}
            </option>
          ))}
        </select>
        <select
          value={category}
          onChange={(e) => setCategory(e.target.value as Category | "all")}
        >
          <option value="all">Category: All</option>
          {CATEGORIES.map((c) => (
            <option key={c} value={c}>
              {CATEGORY_LABELS[c]}
            </option>
          ))}
        </select>
        {hasFilters && (
          <button className="btn-quiet" onClick={clearFilters}>
            Clear filters
          </button>
        )}

        <span className="spacer" />

        {selected.size > 0 && (
          <>
            <span className="hint">{selected.size} selected</span>
            <button
              className="btn-secondary sm"
              disabled={busy}
              onClick={() => void bulkSetStatus("published")}
            >
              Publish
            </button>
            <button
              className="btn-quiet"
              disabled={busy}
              onClick={() => void bulkSetStatus("draft")}
            >
              Unpublish
            </button>
          </>
        )}
      </div>

      {rows === null ? (
        <TableSkeleton />
      ) : filtered.length === 0 ? (
        <div className="empty">
          {rows.length === 0 ? (
            <>
              <p>No destinations yet.</p>
              <button
                className="btn-primary"
                onClick={() => navigate("/destinations/new")}
              >
                Add your first
              </button>
            </>
          ) : (
            <>
              <p>
                {hasFilters
                  ? "Nothing matches those filters."
                  : view === "no-photo"
                    ? "Every place has a photo."
                    : view === "draft"
                      ? "No drafts — everything is published."
                      : "Nothing here yet."}
              </p>
              {hasFilters && (
                <button className="btn-quiet" onClick={clearFilters}>
                  Clear filters
                </button>
              )}
            </>
          )}
        </div>
      ) : (
        <table className="data">
          <thead>
            <tr>
              <th className="tick" />
              <th className="thumb-cell" aria-label="Photo" />
              <th>Name</th>
              <th>Category</th>
              <th>Status</th>
              <th>Last edited</th>
            </tr>
          </thead>
          <tbody>
            {filtered.map((d) => (
              <tr key={d.id} className={selected.has(d.id) ? "on" : undefined}>
                <td className="tick">
                  <input
                    type="checkbox"
                    checked={selected.has(d.id)}
                    onChange={() => toggle(d.id)}
                    aria-label={`Select ${d.name}`}
                  />
                </td>
                <td className="thumb-cell">
                  {d.images[0] ? (
                    <ImageThumb path={d.images[0]} className="row-thumb" />
                  ) : (
                    <div className="thumb row-thumb" />
                  )}
                </td>
                {/* The name opens the place, so there is no separate Edit
                    column; the town is the name's second line rather than a
                    column of its own. */}
                <td>
                  <div className="cell-title">
                    <span>
                      <Link to={`/destinations/${d.id}`}>
                        {d.name || "Untitled destination"}
                      </Link>
                      {d.images.length === 0 && (
                        <span className="badge warn" title="Cannot be published">
                          No photo
                        </span>
                      )}
                    </span>
                    <span className="hint">{d.town || "No town yet"}</span>
                  </div>
                </td>
                <td>{CATEGORY_LABELS[d.category] ?? d.category}</td>
                <td>
                  <span
                    className={
                      d.status === "published" ? "badge ok" : "badge draft"
                    }
                  >
                    {d.status === "published" ? "Published" : "Draft"}
                  </span>
                </td>
                <td className="hint nowrap">
                  {d.updatedAt ? relativeTime(d.updatedAt.toMillis(), now) : "—"}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      )}
    </section>
  );
}

/** Skeleton rows rather than a spinner — the wireframe specifies it, and the
 *  table does not jump when data lands. */
function TableSkeleton() {
  return (
    <table className="data">
      <tbody>
        {Array.from({ length: 6 }, (_, i) => (
          <tr key={i}>
            <td colSpan={6}>
              <div className="skeleton" />
            </td>
          </tr>
        ))}
      </tbody>
    </table>
  );
}
