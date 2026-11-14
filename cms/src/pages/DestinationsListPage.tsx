import { useEffect, useMemo, useState, type MouseEvent } from "react";
import { Link, useNavigate, useSearchParams } from "react-router-dom";
import { listDestinations, setStatus } from "../lib/destinations";
import { listSegments } from "../lib/segments";
import { listExhibits } from "../lib/exhibits";
import { Alert } from "../components/Alert";
import { PageHeader } from "../components/PageHeader";
import { ImageThumb } from "../components/ImageThumb";
import { SelectAll } from "../components/SelectAll";
import { onRowClick } from "../components/row-click";
import { useToast } from "../components/toast-context";
import { relativeTime } from "../types/dashboard";
import { Plus } from "lucide-react";
import {
  CATEGORIES,
  CATEGORY_LABELS,
  type Category,
  type Destination,
  type Status,
} from "../types/destination";
import {
  DESTINATION_VIEWS,
  NO_FILTERS,
  applyFilters,
  bulkStatusMessage,
  planBulkStatus,
  readFilters,
  selectionState,
  toggleAll,
  writeFilters,
  type BulkStatusPlan,
  type DestinationFilters,
  type Subcollections,
} from "../types/list";

/**
 * Admin wireframe screen 3 — Destinations list.
 *
 * The wireframe calls this the shared list pattern for Tours, Guides, AR
 * Content and Users: search, then filters, then bulk actions once rows are
 * selected, sorted by last-updated descending. Keep that shape when the later
 * screens reuse it.
 *
 * What the list is showing (the view, the search, the two filters) lives in
 * its address, not in state: a place opens on its own page, and Back has to
 * return to the list as it was left rather than to "All" with nothing typed.
 */
export function DestinationsListPage() {
  const navigate = useNavigate();
  const toast = useToast();
  const [rows, setRows] = useState<Destination[] | null>(null);
  const [error, setError] = useState<string | null>(null);

  const [params, setParams] = useSearchParams();
  const filters = useMemo(() => readFilters(params), [params]);
  // Replaced, not pushed: each keystroke in the search box would otherwise be
  // a step that Back has to walk through.
  const setFilters = (patch: Partial<DestinationFilters>) =>
    setParams(writeFilters({ ...filters, ...patch }), { replace: true });

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

  const filtered = useMemo(
    () => applyFilters(rows ?? [], filters),
    [rows, filters],
  );

  // A bulk action reaches only the ticked rows on screen. A row ticked and
  // then filtered away keeps its tick, but publishing something nobody can
  // see would be a surprise.
  const visibleIds = useMemo(() => filtered.map((d) => d.id), [filtered]);
  const ticked = useMemo(
    () => visibleIds.filter((id) => selected.has(id)),
    [visibleIds, selected],
  );

  // The view is not a filter to clear: it is which list you are looking at.
  const hasFilters =
    filters.search.trim() !== "" ||
    filters.town !== "all" ||
    filters.category !== "all";

  function clearFilters() {
    setFilters({ ...NO_FILTERS, view: filters.view });
  }

  function toggle(id: string) {
    setSelected((prev) => {
      const next = new Set(prev);
      if (next.has(id)) next.delete(id);
      else next.add(id);
      return next;
    });
  }

  function open(id: string, e: MouseEvent) {
    const to = `/destinations/${id}`;
    if (e.metaKey || e.ctrlKey) window.open(to, "_blank", "noopener");
    else navigate(to);
  }

  async function bulkSetStatus(next: Status) {
    if (!rows) return;
    setBusy(true);
    try {
      const ids = new Set(ticked);
      // Publishing asks what the editor's Publish asks, and two of its
      // questions are about the audio guide and the exhibits, which a list
      // never loads. Fetched only for the places about to go live.
      const subcollections = new Map<string, Subcollections>();
      if (next === "published") {
        await Promise.all(
          rows
            .filter((d) => ids.has(d.id) && d.status !== "published")
            .map(async (d) => {
              const [segments, exhibits] = await Promise.all([
                listSegments(d.id),
                listExhibits(d.id),
              ]);
              subcollections.set(d.id, { segments, exhibits });
            }),
        );
      }
      const plan = planBulkStatus(rows, ids, next, subcollections);
      await Promise.all(plan.change.map((c) => setStatus(c.id, next)));
      // What could not be published stays ticked, so it is easy to find.
      setSelected(new Set(plan.blocked.map((b) => b.id)));
      await reload();
      toast.toast({
        variant: plan.blocked.length > 0 ? "warning" : "success",
        ...bulkStatusMessage(plan, next),
        action:
          plan.change.length > 0
            ? { label: "Undo", onClick: () => void undo(plan.change) }
            : undefined,
      });
    } catch (err) {
      toast.error(
        "That didn't go through",
        err instanceof Error ? err.message : String(err),
      );
      await reload();
    } finally {
      setBusy(false);
    }
  }

  /** Puts each place back to the status it had before the bulk action. */
  async function undo(change: BulkStatusPlan["change"]) {
    setBusy(true);
    try {
      await Promise.all(change.map((c) => setStatus(c.id, c.from)));
      await reload();
      toast.success("Change undone");
    } catch (err) {
      toast.error(
        "Could not undo that",
        err instanceof Error ? err.message : String(err),
      );
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
        {DESTINATION_VIEWS.map((v) => (
          <button
            key={v.id}
            className={filters.view === v.id ? "tab on" : "tab"}
            aria-pressed={filters.view === v.id}
            onClick={() => setFilters({ view: v.id })}
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
          value={filters.search}
          onChange={(e) => setFilters({ search: e.target.value })}
        />
        <select
          value={filters.town}
          onChange={(e) => setFilters({ town: e.target.value })}
        >
          <option value="all">Town: All</option>
          {towns.map((t) => (
            <option key={t} value={t}>
              {t}
            </option>
          ))}
          {/* A town from a link that no place uses any more still has to be
              an option, or the select would show "All" while filtering. */}
          {filters.town !== "all" && !towns.includes(filters.town) && (
            <option value={filters.town}>{filters.town}</option>
          )}
        </select>
        <select
          value={filters.category}
          onChange={(e) =>
            setFilters({ category: e.target.value as Category | "all" })
          }
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

        {ticked.length > 0 && (
          <>
            <span className="hint">{ticked.length} selected</span>
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
                  : filters.view === "no-photo"
                    ? "Every place has a photo."
                    : filters.view === "draft"
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
              <th className="tick">
                <SelectAll
                  state={selectionState(visibleIds, selected)}
                  onToggle={() => setSelected(toggleAll(visibleIds, selected))}
                  noun="places"
                />
              </th>
              <th className="thumb-cell" aria-label="Photo" />
              <th>Name</th>
              <th>Category</th>
              <th>Status</th>
              <th>Last edited</th>
            </tr>
          </thead>
          <tbody>
            {filtered.map((d) => (
              <tr
                key={d.id}
                className={selected.has(d.id) ? "opens on" : "opens"}
                onClick={onRowClick((e) => open(d.id, e))}
              >
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
                    column of its own. The rest of the row opens it too
                    (`onRowClick`), but the name is the link. */}
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
                <td>
                  {CATEGORY_LABELS[d.category] ?? d.category}
                  {d.subcategory && (
                    <span className="hint"> · {d.subcategory}</span>
                  )}
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
