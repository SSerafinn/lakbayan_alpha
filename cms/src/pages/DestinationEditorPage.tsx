import { useEffect, useMemo, useRef, useState } from "react";
import { useBlocker, useNavigate, useParams } from "react-router-dom";
import { CAGAYAN_TOWNS } from "../types/towns";
import {
  createDestination,
  deleteImage,
  getDestination,
  isSlugTaken,
  updateDestination,
  uploadImage,
} from "../lib/destinations";
import { listSegments, saveSegments } from "../lib/segments";
import { Alert } from "../components/Alert";
import { useCrumb } from "../components/crumb-context";
import { PageHeader } from "../components/PageHeader";
import { Dialog } from "../components/Dialog";
import { Field, Section, Toggle } from "../components/Form";
import { useToast } from "../components/toast-context";
import { ImageThumb } from "../components/ImageThumb";
import { AudioGuideTab } from "./AudioGuideTab";
import { formatCoord, searchPlaces, type GeocodeResult } from "../lib/geocode";
import type { SegmentDraft } from "../types/segment";
import {
  CATEGORIES,
  CATEGORY_LABELS,
  MAX_DESCRIPTION,
  emptyDestination,
  publishBlockers,
  readiness,
  slugify,
  validate,
  type Category,
  type Destination,
} from "../types/destination";

type Draft = Omit<Destination, "id">;
type Tab = "details" | "location" | "media" | "audio";

/**
 * Admin wireframe screens 4 and 5 — Destination Editor and Audio Guide.
 *
 * One form across tabs rather than a wizard: the wireframe shows an unsaved
 * banner spanning Details and Media, so tab switching must not lose edits.
 *
 * The audio guide lives in a **subcollection**, not on the destination
 * document, but it shares this page's dirty state, savebar and Ctrl+S all the
 * same. Giving segments their own save-on-every-keystroke would mean two
 * different rules for unsaved work on one screen, and the tab you were not
 * looking at would be the one that behaved differently.
 *
 * AR is still a stub — it arrives with CMS-3.
 */
export function DestinationEditorPage() {
  const { id } = useParams<{ id: string }>();
  const navigate = useNavigate();

  /**
   * The document created during this visit, before the route param catches up.
   *
   * Without it, `id` stays "new" until the navigation lands — and if that
   * navigation is cancelled or delayed, the next save tries to *create* again
   * and fails on the duplicate slug, having already written a document.
   */
  const createdIdRef = useRef<string | null>(null);

  /**
   * Set while we navigate to a freshly-created document.
   *
   * Our own post-save navigation would otherwise trip the unsaved-changes
   * guard: `setSaved` has not been flushed when the blocker predicate runs, so
   * it still sees the draft as dirty and asks whether to discard changes that
   * were just written.
   */
  const bypassBlockerRef = useRef(false);

  const docId = createdIdRef.current ?? id;
  const isNew = id === "new" && createdIdRef.current === null;

  const [draft, setDraft] = useState<Draft | null>(
    isNew ? emptyDestination() : null,
  );
  const [saved, setSaved] = useState<Draft | null>(
    isNew ? emptyDestination() : null,
  );

  // The audio guide, held beside the destination rather than inside it: it is
  // a subcollection, so it loads and writes separately even though the editor
  // presents the two as one document.
  const [segments, setSegments] = useState<SegmentDraft[]>([]);
  const [savedSegments, setSavedSegments] = useState<SegmentDraft[]>([]);

  const [tab, setTab] = useState<Tab>("details");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [slugEdited, setSlugEdited] = useState(!isNew);
  const toast = useToast();

  // Mirrors of state the Ctrl+S handler needs. Refs rather than dependencies so
  // the listener registers once instead of on every keystroke, and still sees
  // current values rather than a stale closure.
  const dirtyRef = useRef(false);
  const busyRef = useRef(false);
  const saveRef = useRef<(() => Promise<unknown>) | null>(null);

  // Keyed on the route param alone, not on `isNew`. `isNew` now flips to false
  // the moment a document is created, which is *before* the route updates —
  // depending on it here would fire a load for the literal id "new".
  useEffect(() => {
    if (!id || id === "new") return;
    void (async () => {
      const found = await getDestination(id);
      if (!found) {
        setError("That destination no longer exists.");
        return;
      }
      const { id: _drop, ...rest } = found;
      setDraft(rest);
      setSaved(rest);

      // Loaded unconditionally rather than when the Audio Guide tab is first
      // opened. The tab shows a count, and `readiness` needs the segments to
      // know whether the guide blocks publishing — both are wrong on a page
      // that has not opened the tab.
      const stops = await listSegments(id);
      setSegments(stops);
      setSavedSegments(stops);
    })();
  }, [id]);

  const dirty = useMemo(
    () =>
      JSON.stringify(draft) !== JSON.stringify(saved) ||
      JSON.stringify(segments) !== JSON.stringify(savedSegments),
    [draft, saved, segments, savedSegments],
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
      !bypassBlockerRef.current &&
      dirty &&
      currentLocation.pathname !== nextLocation.pathname,
  );

  // Clear the bypass once the route has settled on the new document.
  useEffect(() => {
    bypassBlockerRef.current = false;
  }, [id]);

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

  // The top bar's "Destinations / …". Called before the early returns below:
  // a hook cannot sit behind one.
  useCrumb(draft ? draft.name.trim() || "New destination" : null);

  if (error && !draft) {
    return (
      <section className="page">
        <Alert variant="destructive" title="Cannot open this destination">
          {error}
        </Alert>
      </section>
    );
  }
  if (!draft) return <div className="boot">Loading…</div>;

  const set = <K extends keyof Draft>(key: K, value: Draft[K]) =>
    setDraft((d) => (d ? { ...d, [key]: value } : d));

  const errors = validate(draft);
  const checklist = readiness(draft, segments);
  const blockers = publishBlockers(draft, segments);

  /** Is anything on this tab still unmet? Drives the dot on the tab label. */
  const unmetIn = (t: Tab) => checklist.some((i) => !i.ok && i.tab === t);

  /** Publish, or explain why it cannot be published yet. */
  function onPublish() {
    const first = checklist.find((i) => !i.ok);
    if (draft && draft.status !== "published" && first) {
      setTab(first.tab);
      toast.toast({
        variant: "warning",
        title: `Not ready to publish — ${blockers.length} thing${blockers.length === 1 ? "" : "s"} left`,
        description: `${first.label}${first.why ? ` — ${first.why}` : ""}`,
      });
      return;
    }
    void save("published");
  }

  /** Returns the document id on success, null if it did not save. */
  async function save(
    nextStatus?: "draft" | "published",
  ): Promise<string | null> {
    if (!draft) return null;
    const next = nextStatus ? { ...draft, status: nextStatus } : draft;

    const invalid = validate(next);
    if (Object.keys(invalid).length > 0) {
      setTab("details");
      toast.error(
        "Fix the highlighted fields first",
        Object.values(invalid)[0],
      );
      return null;
    }

    setBusy(true);
    try {
      // Exclude this document from the uniqueness check once it exists —
      // otherwise its own slug reads as taken.
      if (await isSlugTaken(next.slug, isNew ? undefined : docId)) {
        setTab("details");
        toast.error(
          "That slug is already taken",
          `"${next.slug}" belongs to another destination. Slugs appear in deep links, so they have to be unique.`,
        );
        return null;
      }

      let savedId: string;
      if (isNew) {
        savedId = await createDestination(next);
        // Record it before navigating: from here on this is an update, even if
        // the navigation is delayed, cancelled, or the user stays put.
        createdIdRef.current = savedId;
      } else {
        savedId = docId!;
        await updateDestination(savedId, next);
      }

      // After the destination, so a brand-new one has a parent document to
      // hang its subcollection from — and before the state below is marked
      // clean, so a failure here still reads as unsaved rather than saved.
      await saveSegments(savedId, segments, savedSegments);

      setDraft(next);
      setSaved(next);
      setSavedSegments(segments);

      if (isNew) {
        bypassBlockerRef.current = true;
        navigate(`/destinations/${savedId}`, { replace: true });
      }

      // The page looks identical after a save — same fields, same values — so
      // without this there is nothing to distinguish "saved" from "nothing
      // happened", which is exactly what made a new draft feel like a
      // duplicate form.
      toast.success(
        nextStatus === "published"
          ? "Published"
          : isNew
            ? "Draft created"
            : "Saved",
        nextStatus === "published"
          ? "It is now visible in the app."
          : "Only you can see it until it is published.",
      );
      return savedId;
    } catch (err) {
      toast.error(
        "That didn't save",
        err instanceof Error ? err.message : String(err),
      );
      return null;
    } finally {
      setBusy(false);
    }
  }

  dirtyRef.current = dirty;
  busyRef.current = busy;
  saveRef.current = () => save();

  return (
    <section className="page editor">
      <PageHeader
        title={draft.name.trim() || "New destination"}
        badge={
          <span
            className={
              draft.status === "published" ? "badge ok" : "badge draft"
            }
          >
            {draft.status === "published" ? "Published" : "Draft"}
          </span>
        }
        meta={
          [draft.town.trim(), CATEGORY_LABELS[draft.category]]
            .filter(Boolean)
            .join(" · ") || undefined
        }
      />

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

      {/* Unsaved state, save failures and publish blockers used to be three
          banners stacked above the form, pushing it down the page and staying
          long after they stopped being useful. They now live where they
          belong: state in the savebar, events in a toast, decisions in the
          dialog above. */}

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
          <button
            className={tab === "audio" ? "tab on" : "tab"}
            onClick={() => setTab("audio")}
          >
            Audio Guide{" "}
            {segments.length > 0 && (
              <span className="hint">{segments.length}</span>
            )}
            {unmetIn("audio") && <span className="tab-dot" />}
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
              destinationId={isNew ? null : docId!}
              set={set}
              onSaveFirst={() => save("draft")}
            />
          )}

          {tab === "audio" && (
            <AudioGuideTab
              destinationId={isNew ? null : docId!}
              destinationName={draft.name}
              segments={segments}
              onChange={setSegments}
              onSaveFirst={() => save("draft")}
            />
          )}
        </div>
      </div>

      <div className="savebar">
        <span className={dirty ? "save-state dirty" : "save-state"}>
          {dirty ? "Unsaved changes · Ctrl+S" : "All changes saved"}
        </span>
        {dirty && (
          <button
            className="btn-quiet"
            onClick={() => {
              setDraft(saved);
              setSegments(savedSegments);
            }}
            disabled={busy}
          >
            Discard
          </button>
        )}
        <span className="spacer" />
        {draft.status !== "published" && blockers.length > 0 && (
          <span className="hint">{blockers.length} left before publishing</span>
        )}
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
        {/* Deliberately NOT disabled when there are blockers. A disabled
            button cannot explain itself, cannot be focused, and gives no
            feedback when clicked — so people click it, nothing happens, and
            they are stuck. Clicking now says what is missing and jumps there. */}
        <button className="btn-primary" disabled={busy} onClick={onPublish}>
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
  onSaveFirst,
}: {
  draft: Draft;
  destinationId: string | null;
  set: <K extends keyof Draft>(k: K, v: Draft[K]) => void;
  /** Creates the draft document and resolves to its id, or null if it failed. */
  onSaveFirst: () => Promise<string | null>;
}) {
  const fileInput = useRef<HTMLInputElement>(null);
  const [uploading, setUploading] = useState(false);
  const toast = useToast();

  async function onPick(files: FileList | null) {
    if (!files?.length) return;
    setUploading(true);
    try {
      // Uploads are keyed by document id, so a brand-new destination has
      // nowhere to put them. Rather than blocking with "save it first" — a
      // wall in front of the thing editors usually reach for first — create
      // the draft silently and carry on.
      const target = destinationId ?? (await onSaveFirst());
      if (!target) return; // The save failed and already reported why.

      const paths: string[] = [];
      let skipped = 0;
      for (const file of Array.from(files)) {
        if (!file.type.startsWith("image/")) {
          skipped++;
          continue;
        }
        paths.push(await uploadImage(target, file));
      }

      if (paths.length > 0) {
        set("images", [...draft.images, ...paths]);
        toast.success(
          `${paths.length} photo${paths.length === 1 ? "" : "s"} added`,
          "Save to keep them.",
        );
      }
      if (skipped > 0) {
        toast.toast({
          variant: "warning",
          title: `${skipped} file${skipped === 1 ? "" : "s"} skipped`,
          description: "Only images can be uploaded.",
        });
      }
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
