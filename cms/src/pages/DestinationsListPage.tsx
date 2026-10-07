import { useEffect, useMemo, useState } from "react";
import { Link, useNavigate } from "react-router-dom";
import { listDestinations, setStatus } from "../lib/destinations";
import { Alert } from "../components/Alert";
import { PageHeader } from "../components/PageHeader";
import { formatDate } from "../types/format";
import { Plus } from "lucide-react";
import {
  CATEGORIES,
  CATEGORY_LABELS,
  type Category,
  type Destination,
  type Status,
} from "../types/destination";

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
  const [status, setStatusFilter] = useState<Status | "all">("all");
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
        (status === "all" || r.status === status),
    );
  }, [rows, search, town, category, status]);

  const hasFilters =
    search.trim() !== "" ||
    town !== "all" ||
    category !== "all" ||
    status !== "all";

  function clearFilters() {
    setSearch("");
    setTown("all");
    setCategory("all");
    setStatusFilter("all");
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
    ? `${rows.length} records · ${rows.filter((r) => r.status === "published").length} published, ${rows.filter((r) => r.status === "draft").length} draft`
    : "Loading…";

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
        <select
          value={status}
          onChange={(e) => setStatusFilter(e.target.value as Status | "all")}
        >
          <option value="all">Status: All</option>
          <option value="published">Published</option>
          <option value="draft">Draft</option>
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
              <p>Nothing matches those filters.</p>
              <button className="btn-quiet" onClick={clearFilters}>
                Clear filters
              </button>
            </>
          )}
        </div>
      ) : (
        <table className="data">
          <thead>
            <tr>
              <th className="tick" />
              <th>Name</th>
              <th>Town</th>
              <th>Category</th>
              <th>Status</th>
              <th>AR</th>
              <th>Last updated</th>
              <th />
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
                <td>
                  <Link to={`/destinations/${d.id}`}>{d.name}</Link>
                  {d.images.length === 0 && (
                    <span className="badge warn" title="Cannot be published">
                      No photo
                    </span>
                  )}
                </td>
                <td>{d.town}</td>
                <td>
                  <span className="badge">
                    {CATEGORY_LABELS[d.category] ?? d.category}
                  </span>
                </td>
                <td>
                  <span
                    className={
                      d.status === "published" ? "badge ok" : "badge draft"
                    }
                  >
                    {d.status === "published" ? "Published" : "Draft"}
                  </span>
                </td>
                <td>{d.hasAR ? "✓" : "—"}</td>
                <td className="hint">
                  {formatDate(d.updatedAt)}
                </td>
                <td>
                  <Link className="btn-quiet sm" to={`/destinations/${d.id}`}>
                    Edit
                  </Link>
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
            <td colSpan={8}>
              <div className="skeleton" />
            </td>
          </tr>
        ))}
      </tbody>
    </table>
  );
}
