import {
  useEffect,
  useMemo,
  useRef,
  useState,
  type ChangeEvent,
} from "react";
import { useBlocker, useNavigate, useParams } from "react-router-dom";
import { useTaxonomy } from "../components/useTaxonomy";
import { useTagVocabulary } from "../components/useTagVocabulary";
import { SuggestInput } from "../components/SuggestInput";
import { suggest } from "../types/fuzzy";
import {
  createDestination,
  deleteImage,
  getDestination,
  isSlugTaken,
  updateDestination,
  uploadImage,
  watchDestination,
} from "../lib/destinations";
import { ImageRejectedError } from "../lib/image";
import { ConflictError } from "../lib/versioned";
import { ConflictDialog } from "../components/ConflictDialog";
import { useAdminNames } from "../components/useAdminNames";
import { useAuth } from "../auth/auth-context";
import { versionOf, whoChanged, type Conflict } from "../types/conflict";
import { listSegments, saveSegments } from "../lib/segments";
import { Alert } from "../components/Alert";
import { useCrumb } from "../components/crumb-context";
import { PageHeader } from "../components/PageHeader";
import { Dialog } from "../components/Dialog";
import { Field, Section, Toggle } from "../components/Form";
import { useInView } from "../components/useInView";
import { useToast } from "../components/toast-context";
import { ImageThumb } from "../components/ImageThumb";
import { AudioGuideTab } from "./AudioGuideTab";
import { formatCoord, searchPlaces, type GeocodeResult } from "../lib/geocode";
import type { SegmentDraft } from "../types/segment";
import { editorActions } from "../types/editor";
import { relativeTime } from "../types/dashboard";
import { CircleAlert, CircleCheck, ImagePlus } from "lucide-react";
import type { Timestamp } from "firebase/firestore";
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
  type ReadinessItem,
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
  // A blank new destination is not wrong yet, it is just empty: field errors
  // wait for the first attempt to save. The checklist in the rail says what
  // is missing in the meantime, without five red "Required"s on arrival.
  const [attempted, setAttempted] = useState(!isNew);
  const toast = useToast();
  const { user } = useAuth();

  /**
   * The version this editor's edits are based on: the document's `updatedAt`
   * when it was loaded, or after this editor's own last save. A save is
   * refused if the stored version has moved on — see types/conflict.ts.
   */
  const versionRef = useRef(0);
  /** True while this editor is writing, so its own save is not mistaken for someone else's. */
  const savingRef = useRef(false);
  /** A save that ran into someone else's: the dialog's question. */
  const [conflict, setConflict] = useState<Conflict | null>(null);
  /** The status that save was for, so "Overwrite with mine" repeats it exactly. */
  const conflictStatusRef = useRef<"draft" | "published" | undefined>(undefined);
  /** Someone else's save, noticed live while this editor is open. */
  const [remote, setRemote] = useState<Conflict | null>(null);
  const loadTheirsRef = useRef<(() => Promise<void>) | null>(null);

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
      versionRef.current = versionOf(found.updatedAt);

      // Loaded unconditionally rather than when the Audio Guide tab is first
      // opened. The tab shows a count, and `readiness` needs the segments to
      // know whether the guide blocks publishing — both are wrong on a page
      // that has not opened the tab.
      const stops = await listSegments(id);
      setSegments(stops);
      setSavedSegments(stops);
    })();
  }, [id]);

  // Another admin's save, noticed as it happens. Without this the first sign
  // was the conflict dialog at save time, after the edits were already made.
  useEffect(() => {
    if (!id || id === "new") return;
    return watchDestination(id, (current) => {
      if (savingRef.current) return;
      if (!current) {
        setRemote({ kind: "deleted" });
        return;
      }
      const at = versionOf(current.updatedAt);
      // 0 until the first load lands; equal when it is this editor's version.
      if (!versionRef.current || at === versionRef.current) return;
      setRemote({
        kind: "changed",
        updatedAt: at,
        updatedBy: current.updatedBy ?? null,
      });
    });
  }, [id]);

  const dirty = useMemo(
    () =>
      JSON.stringify(draft) !== JSON.stringify(saved) ||
      JSON.stringify(segments) !== JSON.stringify(savedSegments),
    [draft, saved, segments, savedSegments],
  );

  // With no edits of its own, the editor simply takes the newer version — there
  // is nothing to lose, and a notice asking permission would be noise. With
  // edits, the notice below explains instead.
  useEffect(() => {
    if (remote?.kind === "changed" && !dirty) void loadTheirsRef.current?.();
  }, [remote, dirty]);

  const remoteBy = remote?.kind === "changed" ? remote.updatedBy : null;
  const names = useAdminNames(Boolean(remoteBy && remoteBy !== user?.uid));

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

  const headRef = useRef<HTMLDivElement>(null);
  const headInView = useInView(headRef, draft !== null);

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

  const errors = attempted ? validate(draft) : {};
  const checklist = readiness(draft, segments);
  const blockers = publishBlockers(draft, segments);

  /** Is anything on this tab still unmet? Drives the dot on the tab label. */
  const unmetIn = (t: Tab) => checklist.some((i) => !i.ok && i.tab === t);

  /** Publish, or explain why it cannot be published yet. */
  function onPublish() {
    // Pressing Publish counts as trying, even when it stops short of saving:
    // the fields it complains about should say why.
    setAttempted(true);
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
    { force = false }: { force?: boolean } = {},
  ): Promise<string | null> {
    if (!draft) return null;
    setAttempted(true);
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
    savingRef.current = true;
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
        // Checked against the version these edits started from, unless the
        // admin has chosen to overwrite.
        await updateDestination(
          savedId,
          next,
          force ? {} : { expected: versionRef.current },
        );
      }

      // After the destination, so a brand-new one has a parent document to
      // hang its subcollection from — and before the state below is marked
      // clean, so a failure here still reads as unsaved rather than saved.
      await saveSegments(savedId, segments, savedSegments);

      // Read back the version this save produced. `updatedAt` is a server
      // timestamp, unknown until the write lands, and the next save is
      // checked against it — keeping the old one would make this editor
      // conflict with itself.
      const fresh = await getDestination(savedId);
      versionRef.current = versionOf(fresh?.updatedAt);
      const stamped = fresh
        ? {
            ...next,
            createdAt: fresh.createdAt,
            updatedAt: fresh.updatedAt,
            updatedBy: fresh.updatedBy,
          }
        : next;

      setDraft(stamped);
      setSaved(stamped);
      setSavedSegments(segments);
      setRemote(null);

      // Photos taken off are deleted only now that the saved version no
      // longer shows them. Deleting on Remove left a broken image behind a
      // Discard.
      for (const path of saved?.images ?? []) {
        if (!next.images.includes(path)) void deleteImage(path);
      }

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
      if (err instanceof ConflictError) {
        conflictStatusRef.current = nextStatus;
        setConflict(err.conflict);
        return null;
      }
      toast.error(
        "That didn't save",
        err instanceof Error ? err.message : String(err),
      );
      return null;
    } finally {
      savingRef.current = false;
      setBusy(false);
    }
  }

  /** Replace everything on screen with the stored version, theirs. */
  async function loadTheirs() {
    if (!docId || isNew) return;
    const found = await getDestination(docId);
    if (!found) {
      setRemote({ kind: "deleted" });
      setConflict(null);
      return;
    }
    const { id: _drop, ...rest } = found;
    const stops = await listSegments(docId);
    versionRef.current = versionOf(found.updatedAt);
    setDraft(rest);
    setSaved(rest);
    setSegments(stops);
    setSavedSegments(stops);
    setConflict(null);
    setRemote(null);
    toast.toast({
      variant: "info",
      title: "Showing the latest version",
      description: "Another save landed while this page was open.",
    });
  }
  loadTheirsRef.current = loadTheirs;

  dirtyRef.current = dirty;
  busyRef.current = busy;
  saveRef.current = () => save();

  const actions = editorActions({ status: draft.status, dirty, isNew });
  const discard = () => {
    setDraft(saved);
    setSegments(savedSegments);
  };
  const actionButtons = (
    <>
      <span className={dirty ? "save-state dirty" : "save-state"}>
        {actions.state}
      </span>
      {actions.discard && (
        <button className="btn-quiet" onClick={discard} disabled={busy}>
          Discard
        </button>
      )}
      {actions.secondary && (
        <button
          className="btn-secondary"
          disabled={busy}
          onClick={() => void save("draft")}
        >
          {actions.secondary === "unpublish" ? "Unpublish" : "Save draft"}
        </button>
      )}
      {/* Deliberately NOT disabled when there are blockers. A disabled
          button cannot explain itself, cannot be focused, and gives no
          feedback when clicked — so people click it, nothing happens, and
          they are stuck. Clicking now says what is missing and jumps there. */}
      {actions.primary && (
        <button className="btn-primary" disabled={busy} onClick={onPublish}>
          {actions.primary === "publish" ? "Publish" : "Save"}
        </button>
      )}
    </>
  );

  return (
    <section className="page editor">
      {/* Observed: when the header and its buttons scroll away with edits
          unsaved, the save bar takes over at the bottom of the screen. */}
      <div ref={headRef}>
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
          actions={actionButtons}
        />
      </div>

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

      <ConflictDialog
        conflict={conflict}
        noun="destination"
        busy={busy}
        onLoadTheirs={() => void loadTheirs()}
        onOverwrite={() => {
          setConflict(null);
          void save(conflictStatusRef.current, { force: true });
        }}
        onDiscard={() => {
          setConflict(null);
          bypassBlockerRef.current = true;
          navigate("/destinations");
        }}
        onDismiss={() => setConflict(null)}
      />

      {remote?.kind === "changed" && dirty && (
        <Alert
          variant="warning"
          title={`${whoChanged(remote.updatedBy, user?.uid, names)} saved changes to this destination ${relativeTime(remote.updatedAt, Date.now())}`}
          actions={
            <button
              className="btn-secondary sm"
              onClick={() => void loadTheirs()}
            >
              Load their version
            </button>
          }
        >
          Your unsaved edits started from the earlier version. Saving will ask
          before replacing theirs; loading theirs discards yours.
        </Alert>
      )}
      {remote?.kind === "deleted" && (
        <Alert
          variant="destructive"
          title="Another admin deleted this destination"
        >
          Anything on screen is all that is left of it, and there is nothing to
          save it to. Copy what you need before you leave.
        </Alert>
      )}

      <nav className="tabs" aria-label="Editor sections">
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
          Photos <span className="tab-count">{draft.images.length}</span>
          {unmetIn("media") && <span className="tab-dot" />}
        </button>
        <button
          className={tab === "audio" ? "tab on" : "tab"}
          onClick={() => setTab("audio")}
        >
          Audio guide{" "}
          {segments.length > 0 && (
            <span className="tab-count">{segments.length}</span>
          )}
          {unmetIn("audio") && <span className="tab-dot" />}
        </button>
        <button className="tab" disabled title="Arrives with the AR work">
          AR
        </button>
      </nav>

      {/* Content on the left, the facts about it on the right — after
          Polaris's product page, which this screen maps onto almost one to
          one. The rail stays put across tabs, so status and the checklist are
          in view while you work on photos or the audio guide. */}
      <div className="editor-grid">
        <div className="editor-main">
          {tab === "details" && (
            <DetailsTab
              draft={draft}
              errors={errors}
              set={set}
              onNameChange={(name) => {
                set("name", name);
                if (!slugEdited) set("slug", slugify(name));
              }}
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

        <aside className="editor-rail" aria-label="About this destination">
          <StatusCard
            status={draft.status}
            checklist={checklist}
            savedAt={saved?.updatedAt}
            onJump={setTab}
          />
          <OrganisationCard draft={draft} errors={errors} set={set} />
          <PlacementCard draft={draft} set={set} />
          <Section title="Link" single>
            <Field
              label="Slug"
              required
              error={errors.slug}
              hint={
                slugEdited
                  ? "Used in deep links — changing it breaks links already shared."
                  : "Follows the name until you edit it."
              }
            >
              <input
                value={draft.slug}
                onChange={(e) => {
                  setSlugEdited(true);
                  set("slug", slugify(e.target.value));
                }}
              />
            </Field>
          </Section>
        </aside>
      </div>

      {dirty && !headInView && (
        <div className="savebar" role="region" aria-label="Unsaved changes">
          {actionButtons}
        </div>
      )}
    </section>
  );
}

type SetField = <K extends keyof Draft>(k: K, v: Draft[K]) => void;

/**
 * The main column's Details tab: what a visitor reads, and the practical
 * facts for the day. Filing and placement moved to the rail beside it.
 */
function DetailsTab({
  draft,
  errors,
  set,
  onNameChange,
}: {
  draft: Draft;
  errors: Record<string, string>;
  set: SetField;
  onNameChange: (name: string) => void;
}) {
  const practical = (key: keyof NonNullable<Draft["practical"]>) => ({
    value: draft.practical?.[key] ?? "",
    onChange: (e: ChangeEvent<HTMLInputElement>) =>
      set("practical", { ...draft.practical, [key]: e.target.value }),
  });

  return (
    <>
      <Section
        title="What visitors read"
        hint="The card, and the top of the place's page in the app."
      >
        <Field label="Name" required error={errors.name} wide>
          <input
            value={draft.name}
            onChange={(e) => onNameChange(e.target.value)}
          />
        </Field>

        <Field
          label="Short description"
          required
          error={errors.description}
          hint={`Shown on cards · ${draft.description.length} / ${MAX_DESCRIPTION}`}
          wide
        >
          <textarea
            rows={3}
            maxLength={MAX_DESCRIPTION}
            value={draft.description}
            onChange={(e) => set("description", e.target.value)}
          />
        </Field>

        <Field label="History and long content" wide>
          <textarea
            rows={8}
            value={draft.history ?? ""}
            onChange={(e) => set("history", e.target.value)}
            placeholder="Background for the place's page: what it is, how it came to be, why it matters."
          />
        </Field>
      </Section>

      {/* Each field labelled. They were four bare inputs whose only label was
          a placeholder, which disappears the moment there is a value — so a
          filled-in form showed "PHP 20" and "Dry season" with nothing to say
          which was which. */}
      <Section
        title="Plan your visit"
        hint="Optional, and shown as written — but it is what makes a listing useful on the ground."
      >
        <Field label="Entry fee">
          <input placeholder="PHP 20" {...practical("entryFee")} />
        </Field>
        <Field label="Opening hours">
          <input
            placeholder="8:00am – 4:00pm daily"
            {...practical("openHours")}
          />
        </Field>
        <Field label="Best season">
          <input
            placeholder="Dry season, November to April"
            {...practical("bestSeason")}
          />
        </Field>
        <Field label="Accessibility">
          <input
            placeholder="184 steps from the road"
            {...practical("accessibility")}
          />
        </Field>
      </Section>
    </>
  );
}

/**
 * Where the place stands, and what stands between it and going live.
 *
 * The checklist used to be a count in the savebar ("3 left before
 * publishing"). It is the same `readiness` list the Publish button checks,
 * now in view on every tab, and each unmet item takes you to its tab.
 */
function StatusCard({
  status,
  checklist,
  savedAt,
  onJump,
}: {
  status: Draft["status"];
  checklist: ReadinessItem[];
  savedAt?: Timestamp;
  onJump: (tab: Tab) => void;
}) {
  const left = checklist.filter((i) => !i.ok).length;
  return (
    <Section
      title="Status"
      hint={
        status === "published"
          ? "Published — visible to everyone in the app."
          : "Draft — only admins can see it."
      }
      single
    >
      <div className="checklist-wrap">
        <p className="overline">
          {left === 0
            ? "Ready to publish"
            : `${left} thing${left === 1 ? "" : "s"} before it can go live`}
        </p>
        <ul className="checklist">
          {checklist.map((item) => (
            <li key={item.label} className={item.ok ? "done" : "todo"}>
              {item.ok ? (
                <CircleCheck size={18} aria-hidden="true" />
              ) : (
                <CircleAlert size={18} aria-hidden="true" />
              )}
              {item.ok ? (
                <span>{item.label}</span>
              ) : (
                <button className="link-button" onClick={() => onJump(item.tab)}>
                  {item.label}
                  {item.why && <span className="hint">{item.why}</span>}
                </button>
              )}
            </li>
          ))}
        </ul>
        {savedAt && (
          <p className="hint">
            Last saved {relativeTime(savedAt.toMillis(), Date.now())}
          </p>
        )}
      </div>
    </Section>
  );
}

/** How the place is filed: the town that groups its offline bundle, its kind, its tags. */
function OrganisationCard({
  draft,
  errors,
  set,
}: {
  draft: Draft;
  errors: Record<string, string>;
  set: SetField;
}) {
  // The province's lists from Settings, or the built-in towns until saved.
  const { towns, subcategories } = useTaxonomy();
  const town = draft.town.trim();
  // A town not on the list is usually a misspelling of one that is.
  const townMatch =
    town && !towns.includes(town) ? suggest(town, towns)[0] : undefined;
  const subOptions = subcategories[draft.category] ?? [];
  const staleSub =
    draft.subcategory && !subOptions.includes(draft.subcategory)
      ? draft.subcategory
      : null;
  return (
    <Section title="Organisation" single>
      {/* The list the town field's `list="towns"` refers to. Without this the
          attribute silently does nothing — which is how "Peñablanca" and
          "Penablanca" end up as two towns, and later two offline bundles. */}
      <datalist id="towns">
        {towns.map((t) => (
          <option key={t} value={t} />
        ))}
      </datalist>

      <Field
        label="Town or municipality"
        required
        error={errors.town}
        hint="Groups its offline bundle, so pick it from the list."
      >
        <input
          value={draft.town}
          onChange={(e) => set("town", e.target.value)}
          list="towns"
          placeholder="Peñablanca"
        />
        {town && !towns.includes(town) && (
          <p className="field-warn">
            Not on the town list.{" "}
            {townMatch ? (
              <button
                className="link-button"
                onClick={() => set("town", townMatch.value)}
              >
                Use {townMatch.value}
              </button>
            ) : (
              "If it is right, add it in Settings."
            )}
          </p>
        )}
      </Field>

      <Field label="Category" required>
        <select
          value={draft.category}
          onChange={(e) => {
            const c = e.target.value as Category;
            set("category", c);
            // A subcategory belongs to its category; one that does not
            // exist under the new category would be meaningless there.
            if (
              draft.subcategory &&
              !(subcategories[c] ?? []).includes(draft.subcategory)
            ) {
              set("subcategory", null);
            }
          }}
        >
          {CATEGORIES.map((c) => (
            <option key={c} value={c}>
              {CATEGORY_LABELS[c]}
            </option>
          ))}
        </select>
      </Field>

      <Field
        label="Subcategory"
        hint={
          subOptions.length || staleSub
            ? "Optional — a finer kind within the category."
            : `None set up under ${CATEGORY_LABELS[draft.category]} yet — add them in Settings.`
        }
      >
        <select
          value={draft.subcategory ?? ""}
          disabled={!subOptions.length && !staleSub}
          onChange={(e) => set("subcategory", e.target.value || null)}
        >
          <option value="">None</option>
          {subOptions.map((s) => (
            <option key={s} value={s}>
              {s}
            </option>
          ))}
          {staleSub && (
            <option value={staleSub}>{staleSub} (no longer in Settings)</option>
          )}
        </select>
      </Field>

      <TagsField tags={draft.tags} onChange={(tags) => set("tags", tags)} />
    </Section>
  );
}

function TagsField({
  tags,
  onChange,
}: {
  tags: string[];
  onChange: (tags: string[]) => void;
}) {
  // Tags already used anywhere, so "cave" offers the "caves" that exists
  // rather than quietly starting a second tag.
  const vocabulary = useTagVocabulary();

  return (
    <Field
      label="Tags"
      hint="Press Enter or a comma after each. Existing tags are offered first."
    >
      <div className="tag-row">
        {tags.map((t) => (
          <span key={t} className="badge">
            {t}
            <button
              className="tag-x"
              aria-label={`Remove ${t}`}
              onClick={() => onChange(tags.filter((x) => x !== t))}
            >
              ×
            </button>
          </span>
        ))}
        <SuggestInput
          label="Add a tag"
          placeholder="Add a tag"
          candidates={vocabulary}
          existing={tags}
          normalizeNew={(s) => s.trim().toLowerCase().replace(/,$/, "")}
          commitKeys={["Enter", ","]}
          commitOnBlur
          onPick={(t) => onChange([...tags, t.toLowerCase()])}
        />
      </div>
    </Field>
  );
}

/** Where it shows up in the app once published, each switch saying what it does. */
function PlacementCard({ draft, set }: { draft: Draft; set: SetField }) {
  const town = draft.town.trim();
  return (
    <Section title="Where it appears" single>
      <div className="toggles">
        <Toggle
          label="Popular places"
          hint="The rail on Explore."
          on={draft.popular}
          onChange={(v) => set("popular", v)}
        />
        <Toggle
          label="Featured"
          hint="Adds the FEATURED badge."
          on={draft.featured}
          onChange={(v) => set("featured", v)}
        />
        <Toggle
          label="Nearby suggestions"
          hint="May be suggested beside other places."
          on={draft.nearbyEligible}
          onChange={(v) => set("nearbyEligible", v)}
        />
        <Toggle
          label="Offline bundle"
          hint={town ? `Downloaded with ${town}.` : "Downloaded with its town."}
          on={draft.offlineEligible}
          onChange={(v) => set("offlineEligible", v)}
        />
        <Toggle
          label="Museum site"
          hint="Enables the AR tab."
          on={draft.isMuseum}
          onChange={(v) => set("isMuseum", v)}
        />
      </div>
    </Section>
  );
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
    <Section
      title="Location"
      hint="Where the pin sits on the map, and what Directions opens."
    >
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
    </Section>
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
      const refused: string[] = [];
      let skipped = 0;
      try {
        for (const file of Array.from(files)) {
          if (!file.type.startsWith("image/")) {
            skipped++;
            continue;
          }
          try {
            paths.push(await uploadImage(target, file));
          } catch (err) {
            // One photo the browser cannot open (an iPhone's HEIC, usually)
            // should not cost the rest of the batch.
            if (!(err instanceof ImageRejectedError)) throw err;
            refused.push(err.message);
          }
        }
      } finally {
        // Keep whatever made it up, even when a later upload failed —
        // otherwise those files sit in Storage with nothing pointing at them.
        if (paths.length > 0) {
          set("images", [...draft.images, ...paths]);
          toast.success(
            `${paths.length} photo${paths.length === 1 ? "" : "s"} added`,
            "Save to keep them.",
          );
        }
      }
      if (refused.length > 0) {
        toast.toast({
          variant: "warning",
          title: `${refused.length} photo${refused.length === 1 ? " was" : "s were"} not added`,
          description: refused.join(" "),
        });
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

  const addTile = (
    <li>
      <button
        className="thumb thumb-add"
        disabled={uploading}
        onClick={() => fileInput.current?.click()}
      >
        <ImagePlus size={22} aria-hidden="true" />
        {uploading ? "Uploading…" : "Add photos"}
      </button>
    </li>
  );

  return (
    <Section
      title="Photos"
      hint="The first photo is the card image. 16:9 crops best. Photos are resized for phones as they upload."
    >
      <div className="media f wide">
        <input
          ref={fileInput}
          type="file"
          accept="image/*"
          multiple
          hidden
          onChange={(e) => void onPick(e.target.files)}
        />

        {/* The add control sits where the next photo will go, rather than in
            a toolbar above the grid. With no photos it is the whole grid, and
            says why one is needed. */}
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
                  }}
                >
                  Remove
                </button>
              </div>
            </li>
          ))}
          {addTile}
        </ul>

        {draft.images.length === 0 && (
          <p className="hint">
            No photos yet — a destination cannot be published without one.
          </p>
        )}
      </div>
    </Section>
  );
}
