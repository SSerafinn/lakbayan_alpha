import { useEffect, useMemo, useRef, useState, type ReactNode } from "react";
import { Link, useBlocker, useNavigate, useParams } from "react-router-dom";
import { CAGAYAN_TOWNS } from "../types/towns";
import {
  createDestination,
  deleteImage,
  getDestination,
  isSlugTaken,
  updateDestination,
  uploadImage,
} from "../lib/destinations";
import { Alert } from "../components/Alert";
import { Dialog } from "../components/Dialog";
import { ImageThumb } from "../components/ImageThumb";
import { formatCoord, searchPlaces, type GeocodeResult } from "../lib/geocode";
import {
  CATEGORIES,
  CATEGORY_LABELS,
  MAX_DESCRIPTION,
  emptyDestination,
  publishBlockers,
  readiness,
  slugify,
  validate,
  type ReadinessItem,
  type Category,
  type Destination,
} from "../types/destination";

type Draft = Omit<Destination, "id">;
type Tab = "details" | "location" | "media";

/**
 * Admin wireframe screen 4 — Destination Editor.
 *
 * One form across tabs rather than a wizard: the wireframe shows an unsaved
 * banner spanning Details and Media, so tab switching must not lose edits.
 *
 * Audio Guide and AR are separate tabs in the wireframe; they arrive with
 * CMS-2 and CMS-3 and are shown disabled so the shape is visible.
 */
export function DestinationEditorPage() {
  const { id } = useParams<{ id: string }>();
  const isNew = id === "new";
  const navigate = useNavigate();

  const [draft, setDraft] = useState<Draft | null>(
    isNew ? emptyDestination() : null,
  );
  const [saved, setSaved] = useState<Draft | null>(
    isNew ? emptyDestination() : null,
  );
  const [tab, setTab] = useState<Tab>("details");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [slugEdited, setSlugEdited] = useState(!isNew);

  // Mirrors of state the Ctrl+S handler needs. Refs rather than dependencies so
  // the listener registers once instead of on every keystroke, and still sees
  // current values rather than a stale closure.
  const dirtyRef = useRef(false);
  const busyRef = useRef(false);
  const saveRef = useRef<(() => Promise<void>) | null>(null);

  useEffect(() => {
    if (isNew || !id) return;
    void (async () => {
      const found = await getDestination(id);
      if (!found) {
        setError("That destination no longer exists.");
        return;
      }
      const { id: _drop, ...rest } = found;
      setDraft(rest);
      setSaved(rest);
    })();
  }, [id, isNew]);

  const dirty = useMemo(
    () => JSON.stringify(draft) !== JSON.stringify(saved),
    [draft, saved],
  );

  // Closing the tab or reloading.
  useEffect(() => {
    if (!dirty) return;
    const onBeforeUnload = (e: BeforeUnloadEvent) => e.preventDefault();
    window.addEventListener("beforeunload", onBeforeUnload);
    return () => window.removeEventListener("beforeunload", onBeforeUnload);
  }, [dirty]);

  // In-app navigation — clicking a sidebar link, the breadcrumb, or the back
  // button. `beforeunload` does not fire for any of these, so without this a
  // click on "Tours" silently threw away every edit. Far more likely than
  // closing the tab, and it was the worst thing about this screen.
  const blocker = useBlocker(
    ({ currentLocation, nextLocation }) =>
      dirty && currentLocation.pathname !== nextLocation.pathname,
  );

  // Ctrl/Cmd+S. Long-form history text plus a photo upload is a lot to lose,
  // and reaching for the mouse to save is the kind of friction that makes
  // people save less often.
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if (!(e.ctrlKey || e.metaKey) || e.key !== "s") return;
      e.preventDefault();
      if (dirtyRef.current && !busyRef.current) void saveRef.current?.();
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, []);

  if (error && !draft) {
    return (
      <Alert variant="destructive" title="Cannot open this destination">
        {error}
      </Alert>
    );
  }
  if (!draft) return <div className="boot">Loading…</div>;

  const set = <K extends keyof Draft>(key: K, value: Draft[K]) =>
    setDraft((d) => (d ? { ...d, [key]: value } : d));

  const errors = validate(draft);
  const checklist = readiness(draft);
  const blockers = publishBlockers(draft);

  /** Is anything on this tab still unmet? Drives the dot on the tab label. */
  const unmetIn = (t: Tab) => checklist.some((i) => !i.ok && i.tab === t);

  async function save(nextStatus?: "draft" | "published") {
    if (!draft) return;
    const next = nextStatus ? { ...draft, status: nextStatus } : draft;

    if (Object.keys(validate(next)).length > 0) {
      setTab("details");
      setError("Fix the highlighted fields first.");
      return;
    }
    if (nextStatus === "published" && publishBlockers(next).length > 0) {
      setError(publishBlockers(next)[0]);
      return;
    }

    setBusy(true);
    setError(null);
    try {
      if (await isSlugTaken(next.slug, isNew ? undefined : id)) {
        setError(
          `The slug "${next.slug}" is already used by another destination.`,
        );
        setTab("details");
        return;
      }

      if (isNew) {
        const newId = await createDestination(next);
        setSaved(next);
        navigate(`/destinations/${newId}`, { replace: true });
      } else {
        await updateDestination(id!, next);
        setDraft(next);
        setSaved(next);
      }
    } catch (err) {
      setError(err instanceof Error ? err.message : String(err));
    } finally {
      setBusy(false);
    }
  }

  dirtyRef.current = dirty;
  busyRef.current = busy;
  saveRef.current = () => save();

  return (
    <section className="page editor">
      <header className="page-head row">
        <div>
          <p className="hint">
            <Link to="/destinations">Destinations</Link> /{" "}
            {draft.name || "New destination"}
          </p>
          <h1>{draft.name || "New destination"}</h1>
        </div>
        <span className="spacer" />
        <span
          className={draft.status === "published" ? "badge ok" : "badge draft"}
        >
          {draft.status === "published" ? "Published" : "Draft"}
        </span>
      </header>

      {/* A genuine decision point — nothing else can proceed until it is
          answered — so this one is modal rather than an inline banner, which
          is easy to miss and would defeat the guard. Escape and a backdrop
          click both map to Stay, the non-destructive choice. */}
      <Dialog
        open={blocker.state === "blocked"}
        onDismiss={() => blocker.reset?.()}
        variant="warning"
        title="You have unsaved changes"
        actions={
          <>
            <button className="btn-quiet" onClick={() => blocker.reset?.()}>
              Stay on this page
            </button>
            <button
              className="btn-secondary"
              onClick={() => blocker.proceed?.()}
            >
              Discard and leave
            </button>
          </>
        }
      >
        Your edits to this destination have not been saved. Leaving now will
        lose them.
      </Dialog>

      {dirty && blocker.state !== "blocked" && (
        <Alert
          variant="info"
          title="Unsaved changes"
          actions={
            <button
              className="btn-quiet"
              onClick={() => setDraft(saved)}
              disabled={busy}
            >
              Discard
            </button>
          }
        >
          Ctrl+S saves.
        </Alert>
      )}

      {error && (
        <Alert variant="destructive" title="That didn't save">
          {error}
        </Alert>
      )}

      <div className="editor-card">
        <nav className="tabs">
          <button
            className={tab === "details" ? "tab on" : "tab"}
            onClick={() => setTab("details")}
          >
            Details
            {unmetIn("details") && <span className="tab-dot" />}
          </button>
          <button
            className={tab === "location" ? "tab on" : "tab"}
            onClick={() => setTab("location")}
          >
            Location
            {unmetIn("location") && <span className="tab-dot" />}
          </button>
          <button
            className={tab === "media" ? "tab on" : "tab"}
            onClick={() => setTab("media")}
          >
            Media <span className="hint">{draft.images.length}</span>
            {unmetIn("media") && <span className="tab-dot" />}
          </button>
          <button className="tab" disabled title="Arrives in CMS-2">
            Audio Guide
          </button>
          <button className="tab" disabled title="Arrives in CMS-3">
            AR
          </button>
        </nav>

        <div className="editor-panel">
          {tab === "details" && (
            <DetailsTab
              draft={draft}
              errors={errors}
              set={set}
              slugEdited={slugEdited}
              onNameChange={(name) => {
                set("name", name);
                if (!slugEdited) set("slug", slugify(name));
              }}
              onSlugEdited={() => setSlugEdited(true)}
            />
          )}

          {tab === "location" && <LocationTab draft={draft} set={set} />}

          {tab === "media" && (
            <MediaTab
              draft={draft}
              destinationId={isNew ? null : id!}
              set={set}
              onError={setError}
            />
          )}
        </div>
      </div>

      {draft.status !== "published" && (
        <ReadinessPanel items={checklist} onJump={setTab} />
      )}

      <div className="savebar">
        <span className="hint">
          {dirty ? "Unsaved changes" : "All changes saved"}
        </span>
        <span className="spacer" />
        {draft.status === "published" ? (
          <button
            className="btn-quiet"
            disabled={busy}
            onClick={() => void save("draft")}
          >
            Unpublish
          </button>
        ) : (
          <button
            className="btn-secondary"
            disabled={busy}
            onClick={() => void save("draft")}
          >
            Save as draft
          </button>
        )}
        <button
          className="btn-primary"
          disabled={
            busy || (draft.status !== "published" && blockers.length > 0)
          }
          onClick={() => void save("published")}
        >
          {draft.status === "published" ? "Save" : "Publish"}
        </button>
      </div>
    </section>
  );
}

function DetailsTab({
  draft,
  errors,
  set,
  slugEdited,
  onNameChange,
  onSlugEdited,
}: {
  draft: Draft;
  errors: Record<string, string>;
  set: <K extends keyof Draft>(k: K, v: Draft[K]) => void;
  slugEdited: boolean;
  onNameChange: (name: string) => void;
  onSlugEdited: () => void;
}) {
  const [tagInput, setTagInput] = useState("");

  return (
    <>
      {/* The list the town field's `list="towns"` refers to. Without this the
          attribute silently does nothing — which is how "Peñablanca" and
          "Penablanca" end up as two towns, and later two offline bundles. */}
      <datalist id="towns">
        {CAGAYAN_TOWNS.map((t) => (
          <option key={t} value={t} />
        ))}
      </datalist>

      <Section title="Identity" hint="How this place is named and filed.">
        <Field label="Name" required error={errors.name}>
          <input
            value={draft.name}
            onChange={(e) => onNameChange(e.target.value)}
          />
        </Field>

        <Field
          label="Slug"
          required
          error={errors.slug}
          hint={
            slugEdited
              ? "Used in deep links — changing it breaks links already shared."
              : "Auto-generated from the name."
          }
        >
          <input
            value={draft.slug}
            onChange={(e) => {
              onSlugEdited();
              set("slug", slugify(e.target.value));
            }}
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
            list="towns"
            placeholder="e.g. Peñablanca"
          />
        </Field>

        <Field label="Category" required>
          <select
            value={draft.category}
            onChange={(e) => set("category", e.target.value as Category)}
          >
            {CATEGORIES.map((c) => (
              <option key={c} value={c}>
                {CATEGORY_LABELS[c]}
              </option>
            ))}
          </select>
        </Field>
      </Section>

      <Section
        title="Content"
        hint="What a visitor reads on the card and the detail screen."
      >
        <Field
          label="Short description"
          required
          error={errors.description}
          hint={`Shown on cards · ${draft.description.length} / ${MAX_DESCRIPTION}`}
          wide
        >
          <textarea
            rows={2}
            maxLength={MAX_DESCRIPTION}
            value={draft.description}
            onChange={(e) => set("description", e.target.value)}
          />
        </Field>

        <Field label="History / long content" wide>
          <textarea
            rows={7}
            value={draft.history ?? ""}
            onChange={(e) => set("history", e.target.value)}
            placeholder="Long-form background shown on the detail screen."
          />
        </Field>
      </Section>

      <Section
        title="Placement"
        hint="Where this appears in the app once published."
      >
        <Field label="Visibility">
          <div className="toggles">
            <Toggle
              label="Show in Popular Places"
              on={draft.popular}
              onChange={(v) => set("popular", v)}
            />
            <Toggle
              label="Featured"
              on={draft.featured}
              onChange={(v) => set("featured", v)}
            />
            <Toggle
              label="Eligible for Nearby Places"
              on={draft.nearbyEligible}
              onChange={(v) => set("nearbyEligible", v)}
            />
            <Toggle
              label="Include in offline bundles"
              on={draft.offlineEligible}
              onChange={(v) => set("offlineEligible", v)}
            />
            <Toggle
              label="Museum site (enables AR)"
              on={draft.isMuseum}
              onChange={(v) => set("isMuseum", v)}
            />
          </div>
        </Field>
      </Section>

      <Section
        title="Visitor information"
        hint="Optional, but it is what turns a listing into something useful on the ground."
      >
        <Field label="Practical info" hint="All optional, shown as written.">
          <div className="pair-grid">
            <input
              placeholder="Entry fee"
              value={draft.practical?.entryFee ?? ""}
              onChange={(e) =>
                set("practical", {
                  ...draft.practical,
                  entryFee: e.target.value,
                })
              }
            />
            <input
              placeholder="Open hours"
              value={draft.practical?.openHours ?? ""}
              onChange={(e) =>
                set("practical", {
                  ...draft.practical,
                  openHours: e.target.value,
                })
              }
            />
            <input
              placeholder="Best season"
              value={draft.practical?.bestSeason ?? ""}
              onChange={(e) =>
                set("practical", {
                  ...draft.practical,
                  bestSeason: e.target.value,
                })
              }
            />
            <input
              placeholder="Accessibility"
              value={draft.practical?.accessibility ?? ""}
              onChange={(e) =>
                set("practical", {
                  ...draft.practical,
                  accessibility: e.target.value,
                })
              }
            />
          </div>
        </Field>

        <Field label="Tags" wide>
          <div className="tag-row">
            {draft.tags.map((t) => (
              <span key={t} className="badge">
                {t}
                <button
                  className="tag-x"
                  aria-label={`Remove ${t}`}
                  onClick={() =>
                    set(
                      "tags",
                      draft.tags.filter((x) => x !== t),
                    )
                  }
                >
                  ×
                </button>
              </span>
            ))}
            <input
              className="tag-input"
              placeholder="add tag, then Enter or comma"
              value={tagInput}
              onChange={(e) => setTagInput(e.target.value)}
              // Commit on Enter, comma, or blur. Enter-only loses a tag whenever
              // someone types it and clicks away, which is most of the time.
              onKeyDown={(e) => {
                if (e.key !== "Enter" && e.key !== ",") return;
                e.preventDefault();
                commitTag();
              }}
              onBlur={commitTag}
            />
          </div>
        </Field>
      </Section>
    </>
  );

  function commitTag() {
    const t = tagInput.trim().toLowerCase().replace(/,$/, "");
    if (t && !draft.tags.includes(t)) set("tags", [...draft.tags, t]);
    setTagInput("");
  }
}

/**
 * Search for a place by name and drop the pin on it.
 *
 * Typing latitude to six decimal places is not a task for a tourism officer.
 * This is the fast path; the numeric fields below remain the source of truth
 * and the fallback for anywhere the geocoder does not know — which in rural
 * Cagayan is plenty of places.
 */
function PlaceSearch({ onPick }: { onPick: (r: GeocodeResult) => void }) {
  const [query, setQuery] = useState("");
  const [results, setResults] = useState<GeocodeResult[] | null>(null);
  const [searching, setSearching] = useState(false);
  const [picked, setPicked] = useState<string | null>(null);

  useEffect(() => {
    const q = query.trim();
    if (q.length < 3) {
      setResults(null);
      return;
    }

    // Debounced, and every superseded keystroke aborts its request. Nominatim's
    // usage policy caps this at one request per second; firing per keystroke
    // would breach it and get the whole province rate-limited.
    const controller = new AbortController();
    setSearching(true);
    const timer = setTimeout(async () => {
      const found = await searchPlaces(q, controller.signal);
      if (!controller.signal.aborted) {
        setResults(found);
        setSearching(false);
      }
    }, 600);

    return () => {
      clearTimeout(timer);
      controller.abort();
    };
  }, [query]);

  return (
    <Field
      label="Find a place"
      wide
      hint="Search by name, then pick a result to set the coordinates."
    >
      <input
        value={query}
        onChange={(e) => {
          setQuery(e.target.value);
          setPicked(null);
        }}
        placeholder="e.g. Callao Cave, Peñablanca"
      />

      {searching && <p className="hint">Searching…</p>}

      {picked && <p className="hint">Pin set to {picked}</p>}

      {!searching && results?.length === 0 && (
        <p className="hint">
          Nothing found. Rural sites are often missing from OpenStreetMap — set
          the coordinates by hand below.
        </p>
      )}

      {!picked && results && results.length > 0 && (
        <ul className="geo-results">
          {results.map((r) => (
            <li key={`${r.lat},${r.lng}`}>
              <button
                className="geo-result"
                onClick={() => {
                  onPick(r);
                  setPicked(r.label);
                  setResults(null);
                }}
              >
                <span>{r.label}</span>
                <span className="hint">
                  {formatCoord(r.lat)}, {formatCoord(r.lng)}
                </span>
              </button>
            </li>
          ))}
        </ul>
      )}
    </Field>
  );
}

function LocationTab({
  draft,
  set,
}: {
  draft: Draft;
  set: <K extends keyof Draft>(k: K, v: Draft[K]) => void;
}) {
  const { lat, lng } = draft.coords;
  // A 0.02-degree box around the pin — roughly 2 km, enough to recognise a spot.
  const bbox = `${lng - 0.01},${lat - 0.01},${lng + 0.01},${lat + 0.01}`;

  return (
    <div className="fgrid">
      <PlaceSearch onPick={(r) => set("coords", { lat: r.lat, lng: r.lng })} />

      <Field label="Latitude" required>
        <input
          type="number"
          step="0.000001"
          value={lat}
          onChange={(e) =>
            set("coords", { ...draft.coords, lat: Number(e.target.value) })
          }
        />
      </Field>
      <Field label="Longitude" required>
        <input
          type="number"
          step="0.000001"
          value={lng}
          onChange={(e) =>
            set("coords", { ...draft.coords, lng: Number(e.target.value) })
          }
        />
      </Field>

      <Field
        label="Preview"
        wide
        hint="Confirms the pin lands where you expect."
      >
        <iframe
          title="Location preview"
          className="map-preview"
          src={`https://www.openstreetmap.org/export/embed.html?bbox=${bbox}&marker=${lat},${lng}`}
        />
        <p className="hint">
          Need coordinates?{" "}
          <a
            href={`https://www.openstreetmap.org/#map=15/${lat}/${lng}`}
            target="_blank"
            rel="noreferrer"
          >
            Open in OpenStreetMap
          </a>{" "}
          — right-click a spot and choose “Show address” to read them off.
        </p>
      </Field>
    </div>
  );
}

function MediaTab({
  draft,
  destinationId,
  set,
  onError,
}: {
  draft: Draft;
  destinationId: string | null;
  set: <K extends keyof Draft>(k: K, v: Draft[K]) => void;
  onError: (m: string) => void;
}) {
  const fileInput = useRef<HTMLInputElement>(null);
  const [uploading, setUploading] = useState(false);

  // Uploads are keyed by document id, so a brand-new destination has nowhere to
  // put them yet. Saving first is the simplest honest answer.
  if (!destinationId) {
    return (
      <div className="empty">
        <p>Save the destination once before adding photos.</p>
        <p className="hint">
          Images are stored under /destinations/&lt;id&gt;/images/, which needs
          the id to exist.
        </p>
      </div>
    );
  }

  async function onPick(files: FileList | null) {
    if (!files?.length) return;
    setUploading(true);
    try {
      const paths: string[] = [];
      for (const file of Array.from(files)) {
        if (!file.type.startsWith("image/")) continue;
        paths.push(await uploadImage(destinationId!, file));
      }
      set("images", [...draft.images, ...paths]);
    } catch (err) {
      onError(err instanceof Error ? err.message : String(err));
    } finally {
      setUploading(false);
      if (fileInput.current) fileInput.current.value = "";
    }
  }

  return (
    <div className="media">
      <div className="row">
        <button
          className="btn-secondary"
          disabled={uploading}
          onClick={() => fileInput.current?.click()}
        >
          {uploading ? "Uploading…" : "Add photos"}
        </button>
        <span className="hint">
          The first image is the card photo. 16:9 crops best.
        </span>
        <input
          ref={fileInput}
          type="file"
          accept="image/*"
          multiple
          hidden
          onChange={(e) => void onPick(e.target.files)}
        />
      </div>

      {draft.images.length === 0 ? (
        <div className="empty">
          <p>No photos yet — a destination cannot be published without one.</p>
        </div>
      ) : (
        <ul className="thumbs">
          {draft.images.map((path, i) => (
            <li key={path}>
              <ImageThumb path={path} />
              <div className="thumb-actions">
                {i === 0 ? (
                  <span className="badge ok">Cover</span>
                ) : (
                  <button
                    className="btn-quiet sm"
                    onClick={() =>
                      set("images", [
                        path,
                        ...draft.images.filter((p) => p !== path),
                      ])
                    }
                  >
                    Make cover
                  </button>
                )}
                <button
                  className="btn-quiet sm"
                  onClick={() => {
                    set(
                      "images",
                      draft.images.filter((p) => p !== path),
                    );
                    void deleteImage(path);
                  }}
                >
                  Remove
                </button>
              </div>
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}

/**
 * What is still missing before this can go live.
 *
 * Replaces a `title` tooltip on a disabled Publish button — which required
 * hovering a disabled control to discover why it was disabled. Each unmet item
 * jumps to the tab that fixes it.
 */
function ReadinessPanel({
  items,
  onJump,
}: {
  items: ReadinessItem[];
  onJump: (tab: Tab) => void;
}) {
  const missing = items.filter((i) => !i.ok);

  if (missing.length === 0) {
    return (
      <Alert variant="success" title="Ready to publish">
        Everything required is filled in.
      </Alert>
    );
  }

  return (
    <Alert
      variant="info"
      title={`${missing.length} thing${missing.length === 1 ? "" : "s"} left before this can be published`}
    >
      <ul>
        {missing.map((i) => (
          <li key={i.label}>
            <button className="link-button" onClick={() => onJump(i.tab)}>
              {i.label}
            </button>
            {i.why && <> — {i.why}</>}
          </li>
        ))}
      </ul>
    </Alert>
  );
}

/** Groups related fields so Details reads as sections, not a wall of inputs. */
function Section({
  title,
  hint,
  children,
}: {
  title: string;
  hint?: string;
  children: ReactNode;
}) {
  return (
    <section className="fsection">
      <header>
        <h2>{title}</h2>
        {hint && <p className="hint">{hint}</p>}
      </header>
      <div className="fgrid">{children}</div>
    </section>
  );
}

function Field({
  label,
  children,
  hint,
  error,
  required,
  wide,
}: {
  label: string;
  children: React.ReactNode;
  hint?: string;
  error?: string;
  required?: boolean;
  wide?: boolean;
}) {
  return (
    <div className={wide ? "f wide" : "f"}>
      <label>
        {label}
        {required && <span className="req">*</span>}
      </label>
      {children}
      {error ? (
        <span className="field-error">{error}</span>
      ) : hint ? (
        <span className="hint">{hint}</span>
      ) : null}
    </div>
  );
}

function Toggle({
  label,
  on,
  onChange,
}: {
  label: string;
  on: boolean;
  onChange: (v: boolean) => void;
}) {
  return (
    <label className="toggle">
      <input
        type="checkbox"
        checked={on}
        onChange={(e) => onChange(e.target.checked)}
      />
      <span>{label}</span>
    </label>
  );
}
