import { useEffect, useMemo, useState } from "react";
import { useSearchParams } from "react-router-dom";
import { BadgeCheck, Plus, Star } from "lucide-react";
import {
  createGuide,
  deleteGuide,
  listGuides,
  setVerified,
  updateGuide,
} from "../lib/guides";
import { Alert, FoldingAlert } from "../components/Alert";
import { PageHeader } from "../components/PageHeader";
import { Dialog } from "../components/Dialog";
import { Field, Section, Toggle } from "../components/Form";
import { SelectAll } from "../components/SelectAll";
import { onRowClick } from "../components/row-click";
import { useToast } from "../components/toast-context";
import { selectionState, toggleAll } from "../types/list";
import { ConflictDialog } from "../components/ConflictDialog";
import { ConflictError } from "../lib/versioned";
import { versionOf, type Conflict } from "../types/conflict";
import { CAGAYAN_TOWNS } from "../types/towns";
import {
  emptyGuide,
  validate,
  type Guide,
  type GuideDraft,
} from "../types/guide";

/**
 * Admin wireframe screen 9 — Local guides directory.
 *
 * Follows the shared list pattern established by the destinations list: search,
 * then filters, then bulk actions once rows are selected.
 *
 * **One screen, not two.** Destinations get a list *and* a separate editor
 * screen; the wireframes give guides a single screen, and a guide is six fields
 * with no media and no tabs — a whole route for that would be ceremony. The
 * editor opens above the table instead. It is not a modal: `Dialog` is reserved
 * for decision points that block everything else, which a form is not. Deleting
 * someone *is* such a point, so that one is modal.
 */
export function GuidesPage() {
  const [rows, setRows] = useState<Guide[] | null>(null);
  const [error, setError] = useState<string | null>(null);
  const toast = useToast();

  const [search, setSearch] = useState("");
  const [town, setTown] = useState("all");
  const [verified, setVerifiedFilter] = useState<"all" | "yes" | "no">("all");
  const [selected, setSelected] = useState<Set<string>>(new Set());
  const [busy, setBusy] = useState(false);

  /** `null` = editor closed. A string id = editing. "new" = adding. */
  const [editing, setEditing] = useState<string | null>(null);
  const [draft, setDraft] = useState<GuideDraft>(emptyGuide());
  const [confirmDelete, setConfirmDelete] = useState<Guide | null>(null);

  /** Returns the guides it loaded, or null if it could not. */
  async function reload(): Promise<Guide[] | null> {
    try {
      const guides = await listGuides();
      setRows(guides);
      setError(null);
      return guides;
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
          r.town.toLowerCase().includes(q) ||
          r.specialties.some((s) => s.toLowerCase().includes(q))) &&
        (town === "all" || r.town === town) &&
        (verified === "all" || r.verified === (verified === "yes")),
    );
  }, [rows, search, town, verified]);

  // A bulk action reaches only the ticked rows on screen, as on Destinations.
  const visibleIds = useMemo(() => filtered.map((g) => g.id), [filtered]);
  const ticked = useMemo(
    () => visibleIds.filter((id) => selected.has(id)),
    [visibleIds, selected],
  );

  const hasFilters =
    search.trim() !== "" || town !== "all" || verified !== "all";

  function clearFilters() {
    setSearch("");
    setTown("all");
    setVerifiedFilter("all");
  }

  function openNew() {
    setDraft(emptyGuide());
    setEditing("new");
  }

  function openEdit(g: Guide) {
    const {
      id: _drop,
      createdAt: _c,
      updatedAt: _u,
      updatedBy: _b,
      ...rest
    } = g;
    setDraft(rest);
    setEditing(g.id);
    setEditingVersion(versionOf(g.updatedAt));
  }

  /** Reopen the editor on the stored entry, dropping the edits on screen. */
  async function loadTheirs() {
    const id = editing;
    const guides = await reload();
    const fresh = guides?.find((g) => g.id === id);
    if (!fresh) {
      setConflict({ kind: "deleted" });
      return;
    }
    openEdit(fresh);
    setConflict(null);
    toast.toast({ variant: "info", title: "Showing the latest version" });
  }

  // Arriving from the dashboard: `?new` opens a blank editor, `?edit=<id>`
  // opens that guide. Consumed once and cleared, as on Tours.
  const [params, setParams] = useSearchParams();
  useEffect(() => {
    if (rows === null) return;
    const edit = params.get("edit");
    if (!params.has("new") && !edit) return;
    if (params.has("new")) {
      openNew();
    } else {
      const g = rows.find((r) => r.id === edit);
      if (g) openEdit(g);
      else toast.error("Guide not found", "They may have been removed since.");
    }
    setParams({}, { replace: true });
  }, [rows, params, setParams, toast]);

  async function save({ force = false }: { force?: boolean } = {}) {
    const errors = validate(draft);
    if (Object.keys(errors).length > 0) {
      toast.error("Fix the highlighted fields first", Object.values(errors)[0]);
      return;
    }
    setBusy(true);
    try {
      const clean: GuideDraft = {
        ...draft,
        name: draft.name.trim(),
        town: draft.town.trim(),
        contact: draft.contact.trim(),
      };
      if (editing === "new") await createGuide(clean);
      else {
        await updateGuide(
          editing!,
          clean,
          force ? {} : { expected: editingVersion },
        );
      }
      setEditing(null);
      await reload();
      toast.success(
        editing === "new" ? "Guide added" : "Saved",
        "Visible to anyone signed in to the app.",
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

  async function doDelete(g: Guide) {
    setBusy(true);
    try {
      await deleteGuide(g.id);
      setConfirmDelete(null);
      if (editing === g.id) setEditing(null);
      setSelected((prev) => {
        const next = new Set(prev);
        next.delete(g.id);
        return next;
      });
      await reload();
      toast.success(`${g.name} removed`, "Their details are gone from the app.");
    } catch (err) {
      toast.error(
        "Could not remove them",
        err instanceof Error ? err.message : String(err),
      );
    } finally {
      setBusy(false);
    }
  }

  async function bulkVerify(next: boolean) {
    setBusy(true);
    try {
      await Promise.all(ticked.map((id) => setVerified(id, next)));
      setSelected(new Set());
      await reload();
    } finally {
      setBusy(false);
    }
  }

  function toggle(id: string) {
    setSelected((prev) => {
      const next = new Set(prev);
      if (next.has(id)) next.delete(id);
      else next.add(id);
      return next;
    });
  }

  const counts = rows
    ? `${rows.length} guide${rows.length === 1 ? "" : "s"} · ${rows.filter((r) => r.verified).length} accredited`
    : "Loading…";

  return (
    <section className="page">
      <PageHeader
        title="Local guides"
        meta={counts}
        actions={
          <button className="btn-primary" onClick={openNew}>
            <Plus size={18} aria-hidden="true" />
            Add guide
          </button>
        }
      />

      {error && (
        <Alert variant="destructive" title="Could not load the directory">
          {error}. Is the emulator running, and do you still have the admin
          claim?
        </Alert>
      )}

      {/* Stated once, at the top, rather than as a warning on the delete
          dialogue where it would arrive too late to inform the decision. */}
      <FoldingAlert id="guides-personal-data" title="This directory holds personal data">
        Every row is a real person's contact details, readable by anyone signed
        in to the app. Add someone only once they have agreed to be listed, and
        remove them promptly if they withdraw.
      </FoldingAlert>

      <ConflictDialog
        conflict={conflict}
        noun="guide"
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
        <GuideEditor
          draft={draft}
          isNew={editing === "new"}
          busy={busy}
          onChange={setDraft}
          onCancel={() => setEditing(null)}
          onSave={() => void save()}
        />
      )}

      <div className="toolbar">
        <input
          className="search"
          placeholder="Search by name, town or specialty"
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
          value={verified}
          onChange={(e) =>
            setVerifiedFilter(e.target.value as "all" | "yes" | "no")
          }
        >
          <option value="all">Accreditation: All</option>
          <option value="yes">Accredited</option>
          <option value="no">Not accredited</option>
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
              onClick={() => void bulkVerify(true)}
            >
              Mark accredited
            </button>
            <button
              className="btn-quiet"
              disabled={busy}
              onClick={() => void bulkVerify(false)}
            >
              Remove accreditation
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
              <p>No guides listed yet.</p>
              <button className="btn-primary" onClick={openNew}>
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
              <th className="tick">
                <SelectAll
                  state={selectionState(visibleIds, selected)}
                  onToggle={() => setSelected(toggleAll(visibleIds, selected))}
                  noun="guides"
                />
              </th>
              <th>Guide</th>
              <th>Specialties</th>
              <th>Contact</th>
              <th>Accredited</th>
              <th>Featured</th>
              <th />
            </tr>
          </thead>
          <tbody>
            {filtered.map((g) => (
              <tr
                key={g.id}
                className={selected.has(g.id) ? "opens on" : "opens"}
                onClick={onRowClick(() => openEdit(g))}
              >
                <td className="tick">
                  <input
                    type="checkbox"
                    checked={selected.has(g.id)}
                    onChange={() => toggle(g.id)}
                    aria-label={`Select ${g.name}`}
                  />
                </td>
                {/* Name, then town: the name opens the guide, so there is no
                    separate Edit button. */}
                <td>
                  <div className="cell-title">
                    <button className="link-button" onClick={() => openEdit(g)}>
                      {g.name}
                    </button>
                    <span className="hint">{g.town}</span>
                  </div>
                </td>
                <td>
                  {g.specialties.length === 0 ? (
                    <span className="hint">—</span>
                  ) : (
                    <div className="tag-row">
                      {g.specialties.map((s) => (
                        <span key={s} className="badge">
                          {s}
                        </span>
                      ))}
                    </div>
                  )}
                </td>
                <td className="hint">{g.contact}</td>
                <td>
                  {g.verified ? (
                    <span className="badge ok">
                      <BadgeCheck size={12} aria-hidden="true" /> Accredited
                    </span>
                  ) : (
                    <span className="badge draft">Not yet</span>
                  )}
                </td>
                <td>
                  {g.featured ? (
                    <span className="badge">
                      <Star size={12} aria-hidden="true" /> Featured
                    </span>
                  ) : (
                    <span className="hint">—</span>
                  )}
                </td>
                <td className="row actions-cell">
                  <button
                    className="btn-quiet sm danger"
                    onClick={() => setConfirmDelete(g)}
                  >
                    Remove
                  </button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      )}

      {/* Modal, unlike the editor: this one is irreversible and it concerns a
          real person, so it should stop everything until it is answered. */}
      <Dialog
        open={confirmDelete !== null}
        onDismiss={() => setConfirmDelete(null)}
        variant="destructive"
        title={`Remove ${confirmDelete?.name ?? ""}?`}
        actions={
          <>
            <button
              className="btn-quiet"
              onClick={() => setConfirmDelete(null)}
            >
              Keep them listed
            </button>
            <button
              className="btn-secondary danger"
              disabled={busy}
              onClick={() => confirmDelete && void doDelete(confirmDelete)}
            >
              Remove
            </button>
          </>
        }
      >
        This deletes their entry outright — there is no unpublish for guides, so
        removing them is how a withdrawn consent is honoured. You will need
        their details again to re-add them.
      </Dialog>
    </section>
  );
}

function GuideEditor({
  draft,
  isNew,
  busy,
  onChange,
  onCancel,
  onSave,
}: {
  draft: GuideDraft;
  isNew: boolean;
  busy: boolean;
  onChange: (next: GuideDraft) => void;
  onCancel: () => void;
  onSave: () => void;
}) {
  const [specialtyInput, setSpecialtyInput] = useState("");
  const errors = validate(draft);

  const set = <K extends keyof GuideDraft>(key: K, value: GuideDraft[K]) =>
    onChange({ ...draft, [key]: value });

  function commitSpecialty() {
    const s = specialtyInput.trim().toLowerCase().replace(/,$/, "");
    if (s && !draft.specialties.includes(s)) {
      set("specialties", [...draft.specialties, s]);
    }
    setSpecialtyInput("");
  }

  return (
    <div className="editor-card guide-editor">
      <div className="editor-panel">
        <datalist id="guide-towns">
          {CAGAYAN_TOWNS.map((t) => (
            <option key={t} value={t} />
          ))}
        </datalist>

        <Section
          title={isNew ? "New guide" : "Edit guide"}
          hint="Shown in the app's guide directory to anyone signed in."
        >
          <Field label="Name" required error={errors.name}>
            <input
              value={draft.name}
              onChange={(e) => set("name", e.target.value)}
              placeholder="e.g. Maria Santos"
            />
          </Field>

          <Field
            label="Town / municipality"
            required
            error={errors.town}
            hint="Start typing — Cagayan's municipalities are suggested."
          >
            <input
              value={draft.town}
              onChange={(e) => set("town", e.target.value)}
              list="guide-towns"
              placeholder="e.g. Peñablanca"
            />
          </Field>

          <Field
            label="Contact"
            required
            error={errors.contact}
            hint="Phone, email, or both — shown exactly as written."
            wide
          >
            <input
              value={draft.contact}
              onChange={(e) => set("contact", e.target.value)}
              placeholder="0917-000-0000 · maria@example.com"
            />
          </Field>

          <Field
            label="Specialties"
            hint="What they guide for. Enter or comma to add."
            wide
          >
            <div className="tag-row">
              {draft.specialties.map((s) => (
                <span key={s} className="badge">
                  {s}
                  <button
                    className="tag-x"
                    aria-label={`Remove ${s}`}
                    onClick={() =>
                      set(
                        "specialties",
                        draft.specialties.filter((x) => x !== s),
                      )
                    }
                  >
                    ×
                  </button>
                </span>
              ))}
              <input
                className="tag-input"
                placeholder="add specialty"
                value={specialtyInput}
                onChange={(e) => setSpecialtyInput(e.target.value)}
                onKeyDown={(e) => {
                  if (e.key !== "Enter" && e.key !== ",") return;
                  e.preventDefault();
                  commitSpecialty();
                }}
                onBlur={commitSpecialty}
              />
            </div>
          </Field>

          <Field label="Listing">
            <div className="toggles">
              <Toggle
                label="Accredited by the province"
                on={draft.verified}
                onChange={(v) => set("verified", v)}
              />
              <Toggle
                label="Featured in the directory"
                on={draft.featured}
                onChange={(v) => set("featured", v)}
              />
            </div>
          </Field>
        </Section>
      </div>

      <div className="savebar">
        <span className="hint">
          {isNew
            ? "Nothing is written until you save."
            : "Changes are live as soon as you save."}
        </span>
        <span className="spacer" />
        <button className="btn-quiet" onClick={onCancel} disabled={busy}>
          Cancel
        </button>
        <button className="btn-primary" onClick={onSave} disabled={busy}>
          {isNew ? "Add guide" : "Save"}
        </button>
      </div>
    </div>
  );
}

function TableSkeleton() {
  return (
    <table className="data">
      <tbody>
        {Array.from({ length: 5 }, (_, i) => (
          <tr key={i}>
            <td colSpan={7}>
              <div className="skeleton" />
            </td>
          </tr>
        ))}
      </tbody>
    </table>
  );
}
