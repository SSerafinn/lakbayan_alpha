import { useEffect, useMemo, useRef, useState } from "react";
import { useSearchParams } from "react-router-dom";
import {
  ChevronDown,
  ChevronUp,
  Plus,
  Star,
  Trash2,
  TriangleAlert,
} from "lucide-react";
import {
  deleteCover,
  deleteTour,
  listTours,
  saveTour,
  tourId,
  uploadCover,
} from "../lib/tours";
import { listDestinations } from "../lib/destinations";
import { Alert } from "../components/Alert";
import { PageHeader } from "../components/PageHeader";
import { relativeTime } from "../types/dashboard";
import { Dialog } from "../components/Dialog";
import { Field, Section, Toggle } from "../components/Form";
import { ImageThumb } from "../components/ImageThumb";
import { useToast } from "../components/toast-context";
import { ConflictDialog } from "../components/ConflictDialog";
import { ConflictError } from "../lib/versioned";
import { versionOf, type Conflict } from "../types/conflict";
import type { Destination } from "../types/destination";
import { emptyTour, validate, type Tour, type TourDraft } from "../types/tour";

/**
 * Admin wireframe screen 8 — Tours.
 *
 * One screen with the editor above the table, the same shape as Local guides
 * and for the same reason: the wireframes draw a single screen for tours, and
 * a second route would be ceremony around four fields and a picker.
 *
 * The picker is the whole screen, really. A tour *is* an ordered list of
 * destinations — the order is the content, not a property of it — so
 * reordering is a first-class action rather than something buried in an edit
 * dialogue.
 */
export function ToursPage() {
  const [rows, setRows] = useState<Tour[] | null>(null);
  const [destinations, setDestinations] = useState<Destination[]>([]);
  const [error, setError] = useState<string | null>(null);
  const toast = useToast();

  const [search, setSearch] = useState("");
  const [featuredOnly, setFeaturedOnly] = useState(false);
  const [busy, setBusy] = useState(false);

  /** `null` = closed, `"new"` = adding, otherwise the id being edited. */
  const [editing, setEditing] = useState<string | null>(null);
  const [draft, setDraft] = useState<TourDraft>(emptyTour());
  const [confirmDelete, setConfirmDelete] = useState<Tour | null>(null);

  /** Returns the tours it loaded, or null if it could not. */
  async function reload(): Promise<Tour[] | null> {
    try {
      const [tours, dests] = await Promise.all([
        listTours(),
        listDestinations(),
      ]);
      setRows(tours);
      setDestinations(dests);
      setError(null);
      return tours;
    } catch (err) {
      setError(err instanceof Error ? err.message : String(err));
      return null;
    }
  }

  // The version the open editor started from, and a save that found another.
  // See types/conflict.ts.
  const [editingVersion, setEditingVersion] = useState(0);
  const [conflict, setConflict] = useState<Conflict | null>(null);

  useEffect(() => {
    void reload();
  }, []);

  const byId = useMemo(
    () => new Map(destinations.map((d) => [d.id, d])),
    [destinations],
  );

  const filtered = useMemo(() => {
    const q = search.trim().toLowerCase();
    return (rows ?? []).filter(
      (t) =>
        (!q || t.title.toLowerCase().includes(q)) &&
        (!featuredOnly || t.featured),
    );
  }, [rows, search, featuredOnly]);

  function openNew() {
    setDraft(emptyTour());
    setEditing("new");
  }

  function openEdit(t: Tour) {
    const {
      id: _drop,
      createdAt: _c,
      updatedAt: _u,
      updatedBy: _b,
      ...rest
    } = t;
    setDraft({ ...rest, description: rest.description ?? "" });
    setEditing(t.id);
    setEditingVersion(versionOf(t.updatedAt));
  }

  /** Reopen the editor on the stored tour, dropping the edits on screen. */
  async function loadTheirs() {
    const id = editing;
    const tours = await reload();
    const fresh = tours?.find((t) => t.id === id);
    if (!fresh) {
      setConflict({ kind: "deleted" });
      return;
    }
    openEdit(fresh);
    setConflict(null);
    toast.toast({ variant: "info", title: "Showing the latest version" });
  }

  // Arriving from the dashboard: `?new` opens a blank editor, `?edit=<id>`
  // opens that tour. Consumed once and cleared, so a reload or a Back does not
  // reopen an editor somebody already closed.
  const [params, setParams] = useSearchParams();
  useEffect(() => {
    if (rows === null) return;
    const edit = params.get("edit");
    if (!params.has("new") && !edit) return;
    if (params.has("new")) {
      openNew();
    } else {
      const t = rows.find((r) => r.id === edit);
      if (t) openEdit(t);
      else toast.error("Tour not found", "It may have been deleted since.");
    }
    setParams({}, { replace: true });
  }, [rows, params, setParams, toast]);

  async function save({ force = false }: { force?: boolean } = {}) {
    const errors = validate(draft);
    if (Object.keys(errors).length > 0) {
      toast.error("Not ready to save", Object.values(errors)[0]);
      return;
    }

    // `saveTour` writes to a derived id, and setDoc has no notion of "already
    // taken" — without this, a new tour sharing a title with an existing one
    // would silently overwrite it.
    if (editing === "new") {
      const clash = (rows ?? []).find((t) => t.id === tourId(draft.title));
      if (clash) {
        toast.error(
          "A tour with that title already exists",
          `"${clash.title}" would be overwritten. Edit that one, or choose a different title.`,
        );
        return;
      }
    }

    setBusy(true);
    try {
      await saveTour(
        draft,
        editing === "new" ? undefined : editing!,
        editing === "new" || force ? {} : { expected: editingVersion },
      );
      setEditing(null);
      await reload();
      toast.success(
        editing === "new" ? "Tour created" : "Saved",
        "Tours are visible in the app as soon as they exist.",
      );
    } catch (err) {
      if (err instanceof ConflictError) {
        setConflict(err.conflict);
        return;
      }
      toast.error(
        "That didn't save",
        err instanceof Error ? err.message : String(err),
      );
    } finally {
      setBusy(false);
    }
  }

  async function doDelete(t: Tour) {
    setBusy(true);
    try {
      await deleteTour(t.id);
      if (t.coverImg) await deleteCover(t.coverImg);
      setConfirmDelete(null);
      if (editing === t.id) setEditing(null);
      await reload();
      toast.success(`${t.title} deleted`);
    } catch (err) {
      toast.error(
        "Could not delete it",
        err instanceof Error ? err.message : String(err),
      );
    } finally {
      setBusy(false);
    }
  }

  /** Stops whose destination is missing or not published — a broken tour. */
  function problems(t: Tour): string[] {
    const out: string[] = [];
    const missing = t.stops.filter((id) => !byId.has(id)).length;
    const unpublished = t.stops.filter(
      (id) => byId.get(id)?.status === "draft",
    ).length;
    if (missing > 0) out.push(`${missing} deleted`);
    if (unpublished > 0) out.push(`${unpublished} unpublished`);
    return out;
  }

  const counts = rows
    ? `${rows.length} tour${rows.length === 1 ? "" : "s"} · ${rows.filter((t) => t.featured).length} featured`
    : "Loading…";

  return (
    <section className="page">
      <PageHeader
        title="Tours"
        meta={counts}
        actions={
          <button className="btn-primary" onClick={openNew}>
            <Plus size={18} aria-hidden="true" />
            New tour
          </button>
        }
      />

      {error && (
        <Alert variant="destructive" title="Could not load tours">
          {error}. Is the emulator running, and do you still have the admin
          claim?
        </Alert>
      )}

      <ConflictDialog
        conflict={conflict}
        noun="tour"
        busy={busy}
        onLoadTheirs={() => void loadTheirs()}
        onOverwrite={() => {
          setConflict(null);
          void save({ force: true });
        }}
        onDiscard={() => {
          setConflict(null);
          setEditing(null);
        }}
        onDismiss={() => setConflict(null)}
      />

      {editing !== null && (
        <TourEditor
          draft={draft}
          isNew={editing === "new"}
          tourIdForUpload={editing === "new" ? tourId(draft.title) : editing}
          destinations={destinations}
          busy={busy}
          onChange={setDraft}
          onCancel={() => setEditing(null)}
          onSave={() => void save()}
        />
      )}

      <div className="toolbar">
        <input
          className="search"
          placeholder="Search by title"
          value={search}
          onChange={(e) => setSearch(e.target.value)}
        />
        <label className="toggle">
          <input
            type="checkbox"
            checked={featuredOnly}
            onChange={(e) => setFeaturedOnly(e.target.checked)}
          />
          <span>Featured only</span>
        </label>
        {(search.trim() !== "" || featuredOnly) && (
          <button
            className="btn-quiet"
            onClick={() => {
              setSearch("");
              setFeaturedOnly(false);
            }}
          >
            Clear filters
          </button>
        )}
      </div>

      {rows === null ? (
        <TableSkeleton />
      ) : filtered.length === 0 ? (
        <div className="empty">
          {rows.length === 0 ? (
            <>
              <p>No tours yet.</p>
              <button className="btn-primary" onClick={openNew}>
                Add your first
              </button>
            </>
          ) : (
            <p>Nothing matches those filters.</p>
          )}
        </div>
      ) : (
        <table className="data">
          <thead>
            <tr>
              <th className="thumb-cell" aria-label="Cover" />
              <th>Tour</th>
              <th>Featured</th>
              <th>Last edited</th>
              <th />
            </tr>
          </thead>
          <tbody>
            {filtered.map((t) => {
              const issues = problems(t);
              const route = t.stops
                .map((id) => byId.get(id)?.name)
                .filter(Boolean)
                .slice(0, 3)
                .join(" → ");
              return (
                <tr key={t.id}>
                  <td className="thumb-cell">
                    {t.coverImg ? (
                      <ImageThumb path={t.coverImg} className="row-thumb" />
                    ) : (
                      <div className="thumb row-thumb" />
                    )}
                  </td>
                  {/* Title, then the route as its second line: the stops are
                      what the tour is, so they belong with its name rather
                      than in a column of their own. */}
                  <td>
                    <div className="cell-title">
                      <span>
                        <button
                          className="link-button"
                          onClick={() => openEdit(t)}
                        >
                          {t.title}
                        </button>
                        {issues.length > 0 && (
                          <span className="badge warn" title="Broken in the app">
                            {issues.join(", ")}
                          </span>
                        )}
                      </span>
                      <span className="hint">
                        {t.stops.length} stop{t.stops.length === 1 ? "" : "s"}
                        {route && ` · ${route}`}
                        {t.stops.length > 3 ? " → …" : ""}
                      </span>
                    </div>
                  </td>
                  <td>
                    {t.featured ? (
                      <span className="badge">
                        <Star size={12} aria-hidden="true" /> Featured
                      </span>
                    ) : (
                      <span className="hint">—</span>
                    )}
                  </td>
                  <td className="hint nowrap">
                    {t.updatedAt
                      ? relativeTime(t.updatedAt.toMillis(), Date.now())
                      : "—"}
                  </td>
                  <td className="row actions-cell">
                    <button
                      className="btn-quiet sm"
                      onClick={() => setConfirmDelete(t)}
                    >
                      Delete
                    </button>
                  </td>
                </tr>
              );
            })}
          </tbody>
        </table>
      )}

      <Dialog
        open={confirmDelete !== null}
        onDismiss={() => setConfirmDelete(null)}
        variant="destructive"
        title={`Delete ${confirmDelete?.title ?? ""}?`}
        actions={
          <>
            <button className="btn-quiet" onClick={() => setConfirmDelete(null)}>
              Keep it
            </button>
            <button
              className="btn-secondary"
              disabled={busy}
              onClick={() => confirmDelete && void doDelete(confirmDelete)}
            >
              Delete
            </button>
          </>
        }
      >
        The destinations it points at are not affected — only the itinerary is
        removed. There is no unpublish for tours, so this is how one comes down.
      </Dialog>
    </section>
  );
}

function TourEditor({
  draft,
  isNew,
  tourIdForUpload,
  destinations,
  busy,
  onChange,
  onCancel,
  onSave,
}: {
  draft: TourDraft;
  isNew: boolean;
  tourIdForUpload: string;
  destinations: Destination[];
  busy: boolean;
  onChange: (next: TourDraft) => void;
  onCancel: () => void;
  onSave: () => void;
}) {
  const fileInput = useRef<HTMLInputElement>(null);
  const [uploading, setUploading] = useState(false);
  const toast = useToast();
  const errors = validate(draft);

  const set = <K extends keyof TourDraft>(key: K, value: TourDraft[K]) =>
    onChange({ ...draft, [key]: value });

  async function onPickCover(files: FileList | null) {
    const file = files?.[0];
    if (!file) return;
    if (!file.type.startsWith("image/")) {
      toast.toast({
        variant: "warning",
        title: "That file was not uploaded",
        description: "A cover has to be an image.",
      });
      return;
    }
    // The upload path is keyed by the tour id, which comes from the title —
    // so there is nowhere to put a cover until the tour has one.
    if (!tourIdForUpload) {
      toast.error("Give the tour a title first", "The cover is stored under it.");
      return;
    }
    setUploading(true);
    try {
      set("coverImg", await uploadCover(tourIdForUpload, file, draft.coverImg));
      toast.success("Cover uploaded", "Save to keep it.");
    } catch (err) {
      toast.error(
        "Upload failed",
        err instanceof Error ? err.message : String(err),
      );
    } finally {
      setUploading(false);
      if (fileInput.current) fileInput.current.value = "";
    }
  }

  return (
    <div className="editor-card tour-editor">
      <div className="editor-panel">
        <Section
          title={isNew ? "New tour" : "Edit tour"}
          hint="Visible in the app as soon as it is saved — tours have no draft state."
        >
          <Field label="Title" required error={errors.title} wide>
            <input
              value={draft.title}
              onChange={(e) => set("title", e.target.value)}
              placeholder="e.g. Peñablanca caves in a day"
            />
          </Field>

          <Field
            label="Description"
            hint="What the tour is, and who it suits."
            wide
          >
            <textarea
              rows={3}
              value={draft.description ?? ""}
              onChange={(e) => set("description", e.target.value)}
            />
          </Field>

          <Field label="Cover image" hint="16:9 crops best, as on destinations.">
            <div className="segment-audio">
              <button
                className="btn-secondary sm"
                disabled={uploading || busy}
                onClick={() => fileInput.current?.click()}
              >
                {uploading
                  ? "Uploading…"
                  : draft.coverImg
                    ? "Replace"
                    : "Upload"}
              </button>
              {draft.coverImg && (
                <button
                  className="btn-quiet sm"
                  onClick={() => {
                    const path = draft.coverImg!;
                    set("coverImg", undefined);
                    void deleteCover(path);
                  }}
                >
                  Remove
                </button>
              )}
              <input
                ref={fileInput}
                type="file"
                accept="image/*"
                hidden
                onChange={(e) => void onPickCover(e.target.files)}
              />
            </div>
            {draft.coverImg && (
              <ImageThumb path={draft.coverImg} className="cover-preview" />
            )}
          </Field>

          <Field label="Placement">
            <div className="toggles">
              <Toggle
                label="Featured"
                on={draft.featured}
                onChange={(v) => set("featured", v)}
              />
            </div>
          </Field>
        </Section>

        <StopPicker
          stops={draft.stops}
          destinations={destinations}
          error={errors.stops}
          onChange={(next) => set("stops", next)}
        />
      </div>

      <div className="savebar">
        <span className="hint">
          {isNew
            ? "Nothing is written until you save."
            : "Changes go live as soon as you save."}
        </span>
        <span className="spacer" />
        <button className="btn-quiet" onClick={onCancel} disabled={busy}>
          Cancel
        </button>
        <button className="btn-primary" onClick={onSave} disabled={busy}>
          {isNew ? "Create tour" : "Save"}
        </button>
      </div>
    </div>
  );
}

/**
 * Pick destinations and put them in order.
 *
 * Move up/down rather than drag, the same call as the audio guide segments:
 * a handful of stops, and buttons are reachable from the keyboard and
 * announced by a screen reader without the code hand-rolled dragging needs.
 */
function StopPicker({
  stops,
  destinations,
  error,
  onChange,
}: {
  stops: string[];
  destinations: Destination[];
  error?: string;
  onChange: (next: string[]) => void;
}) {
  const [toAdd, setToAdd] = useState("");
  const byId = useMemo(
    () => new Map(destinations.map((d) => [d.id, d])),
    [destinations],
  );

  const available = useMemo(
    () =>
      destinations
        .filter((d) => !stops.includes(d.id))
        .sort((a, b) => a.name.localeCompare(b.name)),
    [destinations, stops],
  );

  function move(index: number, by: -1 | 1) {
    const to = index + by;
    if (to < 0 || to >= stops.length) return;
    const next = [...stops];
    [next[index], next[to]] = [next[to], next[index]];
    onChange(next);
  }

  const unpublished = stops.filter((id) => byId.get(id)?.status === "draft");
  const missing = stops.filter((id) => !byId.has(id));

  return (
    <section className="fsection">
      <header>
        <h2>Stops</h2>
        <p className="hint">
          In visiting order. The order is the tour — the app walks it top to
          bottom.
        </p>
      </header>

      <div className="stop-add row">
        <select value={toAdd} onChange={(e) => setToAdd(e.target.value)}>
          <option value="">Add a destination…</option>
          {available.map((d) => (
            <option key={d.id} value={d.id}>
              {d.name} · {d.town}
              {d.status === "draft" ? " (draft)" : ""}
            </option>
          ))}
        </select>
        <button
          className="btn-secondary sm"
          disabled={!toAdd}
          onClick={() => {
            onChange([...stops, toAdd]);
            setToAdd("");
          }}
        >
          Add stop
        </button>
        {available.length === 0 && destinations.length > 0 && (
          <span className="hint">Every destination is already on this tour.</span>
        )}
      </div>

      {error && <span className="field-error">{error}</span>}

      {/* A tour is public the moment it is saved, so a stop the app cannot
          show is a live defect rather than a note for later. */}
      {(unpublished.length > 0 || missing.length > 0) && (
        <Alert variant="warning" title="Some stops will not appear in the app">
          <ul>
            {unpublished.length > 0 && (
              <li>
                {unpublished.length} stop
                {unpublished.length === 1 ? " is" : "s are"} still a draft.
                Publish the destination and it appears here.
              </li>
            )}
            {missing.length > 0 && (
              <li>
                {missing.length} stop
                {missing.length === 1 ? "" : "s"} point at a destination that no
                longer exists. Remove {missing.length === 1 ? "it" : "them"}.
              </li>
            )}
          </ul>
        </Alert>
      )}

      {stops.length === 0 ? (
        <div className="empty">
          <p>No stops yet. A tour needs at least one.</p>
        </div>
      ) : (
        <ol className="stop-list">
          {stops.map((id, i) => {
            const d = byId.get(id);
            return (
              <li className="stop" key={`${id}-${i}`}>
                <span className="segment-no">{i + 1}</span>
                <div className="stop-body">
                  {d ? (
                    <>
                      <strong>{d.name}</strong>
                      <span className="hint">
                        {d.town}
                        {d.status === "draft" && " · draft"}
                      </span>
                    </>
                  ) : (
                    <>
                      <strong className="stop-missing">
                        <TriangleAlert size={13} aria-hidden="true" /> Deleted
                        destination
                      </strong>
                      <span className="hint">{id}</span>
                    </>
                  )}
                </div>
                <div className="segment-order">
                  <button
                    className="btn-quiet sm"
                    onClick={() => move(i, -1)}
                    disabled={i === 0}
                    aria-label={`Move stop ${i + 1} earlier`}
                  >
                    <ChevronUp size={16} aria-hidden="true" />
                  </button>
                  <button
                    className="btn-quiet sm"
                    onClick={() => move(i, 1)}
                    disabled={i === stops.length - 1}
                    aria-label={`Move stop ${i + 1} later`}
                  >
                    <ChevronDown size={16} aria-hidden="true" />
                  </button>
                </div>
                <button
                  className="btn-quiet sm"
                  onClick={() => onChange(stops.filter((_, x) => x !== i))}
                  aria-label={`Remove stop ${i + 1}`}
                >
                  <Trash2 size={16} aria-hidden="true" />
                </button>
              </li>
            );
          })}
        </ol>
      )}
    </section>
  );
}

function TableSkeleton() {
  return (
    <table className="data">
      <tbody>
        {Array.from({ length: 4 }, (_, i) => (
          <tr key={i}>
            <td colSpan={5}>
              <div className="skeleton" />
            </td>
          </tr>
        ))}
      </tbody>
    </table>
  );
}
