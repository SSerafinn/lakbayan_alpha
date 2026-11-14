import { useEffect, useMemo, useRef, useState } from "react";
import { useBlocker } from "react-router-dom";
import { ArrowDown, ArrowUp, Plus, Trash2 } from "lucide-react";
import type { Timestamp } from "firebase/firestore";
import { Alert } from "../components/Alert";
import { ConflictDialog } from "../components/ConflictDialog";
import { Dialog } from "../components/Dialog";
import { Field, Section } from "../components/Form";
import { PageHeader } from "../components/PageHeader";
import { useToast } from "../components/toast-context";
import { SuggestInput } from "../components/SuggestInput";
import { refreshTaxonomy } from "../components/useTaxonomy";
import { refreshTagVocabulary } from "../components/useTagVocabulary";
import {
  clearSubcategory,
  listDestinations,
  renameTown,
  retagDestinations,
} from "../lib/destinations";
import { capitalise, suggest } from "../types/fuzzy";
import {
  getSettings,
  nowStamp,
  saveSettings,
  toTimestamp,
} from "../lib/settings";
import { ConflictError } from "../lib/versioned";
import type { Conflict } from "../types/conflict";
import { relativeTime } from "../types/dashboard";
import {
  CATEGORIES,
  CATEGORY_LABELS,
  type Category,
  type Destination,
} from "../types/destination";
import { formatDate } from "../types/format";
import {
  MAX_ANNOUNCEMENT,
  announcementState,
  cleanHotlines,
  cleanSubcategories,
  dateInputFromUntil,
  emptyApp,
  emptyPolicies,
  hotlineProblem,
  normalizeTowns,
  subcategoryUsage,
  tagUsage,
  townsNotListed,
  untilFromDateInput,
  type AppSettings,
  type PolicySettings,
  type SettingsId,
  type Stamped,
  type TaxonomySettings,
} from "../types/settings";
import { CAGAYAN_TOWNS } from "../types/towns";

type Tab = "taxonomy" | "app" | "policies";

const TABS: { id: Tab; label: string }[] = [
  { id: "taxonomy", label: "Towns and tags" },
  { id: "app", label: "Contact and notices" },
  { id: "policies", label: "Policies" },
];

/**
 * One settings document's editing state: draft, what is saved, and the
 * version the draft started from, with the same conflict check as every
 * other editor (see types/conflict.ts).
 */
function useSettingsDoc<T extends object>(
  id: SettingsId,
  empty: () => T,
  pick: (raw: T & Stamped) => T,
) {
  const [draft, setDraft] = useState<T | null>(null);
  const [saved, setSaved] = useState<T | null>(null);
  const [savedAt, setSavedAt] = useState<Timestamp | undefined>(undefined);
  const [exists, setExists] = useState(false);
  const [conflict, setConflict] = useState<Conflict | null>(null);
  const [busy, setBusy] = useState(false);
  /** A failed load: shown in place of the tab, not a skeleton that never ends. */
  const [error, setError] = useState<string | null>(null);
  const version = useRef(0);

  async function load() {
    let got: Awaited<ReturnType<typeof getSettings<T>>>;
    try {
      got = await getSettings<T>(id);
    } catch (err) {
      setError(err instanceof Error ? err.message : String(err));
      return;
    }
    setError(null);
    const { data, version: v } = got;
    const value = data ? pick(data) : empty();
    version.current = v;
    setDraft(value);
    setSaved(value);
    setSavedAt(data?.updatedAt);
    setExists(Boolean(data));
    setConflict(null);
  }

  useEffect(() => {
    void load();
    // `load` is stable in effect: it reads only its arguments and setters.
    // oxlint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const dirty =
    draft !== null && JSON.stringify(draft) !== JSON.stringify(saved);

  /** True when it saved; false on a conflict, which the dialog then asks about. */
  async function save(
    write: { data: object; extra?: object },
    { force = false }: { force?: boolean } = {},
  ): Promise<boolean> {
    setBusy(true);
    try {
      await saveSettings(id, write.data, {
        expected: force ? undefined : version.current,
        extra: write.extra,
      });
      await load(); // server values back: the new version, a policy's date
      return true;
    } catch (err) {
      if (err instanceof ConflictError) {
        setConflict(err.conflict);
        return false;
      }
      throw err;
    } finally {
      setBusy(false);
    }
  }

  return {
    error,
    draft,
    setDraft,
    saved,
    savedAt,
    exists,
    dirty,
    conflict,
    setConflict,
    busy,
    save,
    load,
    discard: () => setDraft(saved),
  };
}

/**
 * Admin wireframe screen 11 — Settings.
 *
 * Three documents, three tabs: the town list and tags, what the app tells
 * visitors directly (the office, emergency lines, a notice), and the
 * policies. Each saves on its own, so a half-finished policy does not hold
 * up a corrected hotline.
 *
 * The app does not show the second and third yet — they are written ahead
 * of the screens that will (PLAN.md, Phase 5), and each tab says so.
 */
export function SettingsPage() {
  const toast = useToast();
  const [tab, setTab] = useState<Tab>("taxonomy");
  const [destinations, setDestinations] = useState<Destination[] | null>(null);

  const taxonomy = useSettingsDoc<TaxonomySettings>(
    "taxonomy",
    () => ({ towns: [...CAGAYAN_TOWNS], subcategories: {} }),
    (raw) => ({ towns: raw.towns ?? [], subcategories: raw.subcategories ?? {} }),
  );
  const app = useSettingsDoc<AppSettings>("app", emptyApp, (raw) => ({
    contact: raw.contact ?? {},
    hotlines: raw.hotlines ?? [],
    announcement: raw.announcement ?? null,
  }));
  const policies = useSettingsDoc<PolicySettings>(
    "policies",
    emptyPolicies,
    (raw) => ({
      privacy: raw.privacy ?? "",
      terms: raw.terms ?? "",
      privacyUpdatedAt: raw.privacyUpdatedAt ?? null,
      termsUpdatedAt: raw.termsUpdatedAt ?? null,
    }),
  );

  async function reloadDestinations() {
    setDestinations(await listDestinations());
  }
  useEffect(() => {
    void reloadDestinations();
  }, []);

  const current = { taxonomy, app, policies }[tab];
  const unsavedDefaults =
    tab === "taxonomy" &&
    taxonomy.draft !== null &&
    !taxonomy.exists &&
    !taxonomy.dirty;
  const anyDirty = taxonomy.dirty || app.dirty || policies.dirty;

  // The same guards as the destination editor: closing the tab, and leaving
  // through the sidebar, both ask first.
  useEffect(() => {
    if (!anyDirty) return;
    const onBeforeUnload = (e: BeforeUnloadEvent) => e.preventDefault();
    window.addEventListener("beforeunload", onBeforeUnload);
    return () => window.removeEventListener("beforeunload", onBeforeUnload);
  }, [anyDirty]);
  const blocker = useBlocker(
    ({ currentLocation, nextLocation }) =>
      anyDirty && currentLocation.pathname !== nextLocation.pathname,
  );

  async function saveCurrent({ force = false }: { force?: boolean } = {}) {
    try {
      let ok = false;
      if (tab === "taxonomy" && taxonomy.draft) {
        const towns = normalizeTowns(taxonomy.draft.towns);
        if (towns.length === 0) {
          toast.error("Keep at least one town", "The town field needs a list to offer.");
          return;
        }
        ok = await taxonomy.save(
          {
            data: {
              towns,
              subcategories: cleanSubcategories(taxonomy.draft.subcategories),
            },
          },
          { force },
        );
        if (ok) refreshTaxonomy();
      }
      if (tab === "app" && app.draft) {
        const problem = hotlineProblem(app.draft.hotlines);
        if (problem) {
          toast.error("Check the hotlines", problem);
          return;
        }
        const a = app.draft.announcement;
        ok = await app.save(
          {
            data: {
              contact: trimContact(app.draft.contact),
              hotlines: cleanHotlines(app.draft.hotlines),
              announcement: a?.text.trim()
                ? { text: a.text.trim(), until: a.until ?? null }
                : null,
            },
          },
          { force },
        );
      }
      if (tab === "policies" && policies.draft && policies.saved) {
        const d = policies.draft;
        const s = policies.saved;
        // Each policy's date moves only when its own text changed: that date
        // is what a reader is told, and a typo fix in the terms must not
        // claim the privacy policy changed too.
        ok = await policies.save(
          {
            data: {
              privacy: d.privacy,
              terms: d.terms,
              privacyUpdatedAt: s.privacyUpdatedAt ?? null,
              termsUpdatedAt: s.termsUpdatedAt ?? null,
            },
            extra: {
              ...(d.privacy !== s.privacy ? { privacyUpdatedAt: nowStamp() } : {}),
              ...(d.terms !== s.terms ? { termsUpdatedAt: nowStamp() } : {}),
            },
          },
          { force },
        );
      }
      if (ok) toast.success("Settings saved");
    } catch (err) {
      toast.error(
        "That didn't save",
        err instanceof Error ? err.message : String(err),
      );
    }
  }

  return (
    <section className="page settings">
      <PageHeader
        title="Settings"
        meta="What the province sets once and changes rarely."
      />

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
        Some settings have not been saved. Leaving now will lose them.
      </Dialog>

      <ConflictDialog
        conflict={current.conflict}
        noun="setting"
        busy={current.busy}
        onLoadTheirs={() => void current.load()}
        onOverwrite={() => {
          current.setConflict(null);
          void saveCurrent({ force: true });
        }}
        onDiscard={() => {
          current.setConflict(null);
          void current.load();
        }}
        onDismiss={() => current.setConflict(null)}
      />

      <nav className="tabs" aria-label="Settings sections">
        {TABS.map((t) => {
          const dirty = { taxonomy, app, policies }[t.id].dirty;
          return (
            <button
              key={t.id}
              className={tab === t.id ? "tab on" : "tab"}
              onClick={() => setTab(t.id)}
            >
              {t.label}
              {dirty && (
                <span className="tab-dot" aria-label="Unsaved changes" />
              )}
            </button>
          );
        })}
      </nav>

      <div className="settings-body">
        {current.error ? (
          <Alert variant="destructive" title="Could not load these settings">
            {current.error}. Is the emulator running with the current
            firestore.rules, and do you still have the admin claim?
          </Alert>
        ) : current.draft === null ? (
          <div className="panel-loading" aria-busy="true">
            <div className="skeleton" />
            <div className="skeleton" />
          </div>
        ) : tab === "taxonomy" ? (
          <TaxonomyTab
            value={taxonomy.draft!}
            exists={taxonomy.exists}
            destinations={destinations}
            update={(fn) => taxonomy.setDraft((d) => (d ? fn(d) : d))}
            onDestinationsChanged={() => void reloadDestinations()}
          />
        ) : tab === "app" ? (
          <AppTab value={app.draft!} onChange={app.setDraft} />
        ) : (
          <PoliciesTab value={policies.draft!} onChange={policies.setDraft} />
        )}
      </div>

      {current.dirty && (
        <div className="savebar" role="region" aria-label="Unsaved changes">
          <span className="save-state dirty">Unsaved changes</span>
          <button
            className="btn-quiet"
            onClick={current.discard}
            disabled={current.busy}
          >
            Discard
          </button>
          <button
            className="btn-primary"
            onClick={() => void saveCurrent()}
            disabled={current.busy}
          >
            Save
          </button>
        </div>
      )}
      {/* The built-in town list on a project that has never saved one. The
          Towns card says "Save to make it the province's", and with no edit
          to make there was no Save to press. Not "dirty": there is nothing
          to lose, so leaving does not ask. */}
      {unsavedDefaults && (
        <div className="savebar" role="region" aria-label="Not saved yet">
          <span className="save-state">Not saved yet</span>
          <button
            className="btn-primary"
            onClick={() => void saveCurrent()}
            disabled={current.busy}
          >
            Save this list
          </button>
        </div>
      )}
      {!current.dirty && current.savedAt && (
        <p className="hint settings-saved">
          Last saved {relativeTime(current.savedAt.toMillis(), Date.now())}
        </p>
      )}
    </section>
  );
}

function trimContact(c: AppSettings["contact"]): AppSettings["contact"] {
  return Object.fromEntries(
    Object.entries(c)
      .map(([k, v]) => [k, (v ?? "").trim()])
      .filter(([, v]) => v),
  );
}

// ---- towns and tags -----------------------------------------------------------

type TaxonomyUpdate = (
  fn: (v: TaxonomySettings) => TaxonomySettings,
) => void;

function TaxonomyTab({
  value,
  exists,
  destinations,
  update,
  onDestinationsChanged,
}: {
  value: TaxonomySettings;
  exists: boolean;
  destinations: Destination[] | null;
  /** Functional, so an Undo restores what it removed even after other edits. */
  update: TaxonomyUpdate;
  onDestinationsChanged: () => void;
}) {
  return (
    <>
      <TownsSection
        towns={value.towns}
        exists={exists}
        destinations={destinations}
        update={update}
        onDestinationsChanged={onDestinationsChanged}
      />
      <SubcategoriesSection
        value={value.subcategories}
        destinations={destinations}
        update={update}
        onDestinationsChanged={onDestinationsChanged}
      />
      <TagsSection
        destinations={destinations}
        onRetagged={onDestinationsChanged}
      />
    </>
  );
}

/**
 * The town list, built by picking rather than typing.
 *
 * The add field searches Cagayan's official towns and offers the official
 * spelling for anything close — "Penablanca", "Penablanka" and "penablanca"
 * all offer Peñablanca, and Enter takes it. A name that is not an official
 * town is the last option, never the default, and says so. Removing a town
 * that places use asks first; any removal can be undone from the toast.
 */
function TownsSection({
  towns,
  exists,
  destinations,
  update,
  onDestinationsChanged,
}: {
  towns: string[];
  exists: boolean;
  destinations: Destination[] | null;
  update: TaxonomyUpdate;
  onDestinationsChanged: () => void;
}) {
  const toast = useToast();
  const inUse = useMemo(() => {
    const m = new Map<string, number>();
    for (const d of destinations ?? []) {
      const t = d.town.trim();
      if (t) m.set(t, (m.get(t) ?? 0) + 1);
    }
    return m;
  }, [destinations]);
  const missing = useMemo(
    () => townsNotListed(destinations ?? [], towns),
    [destinations, towns],
  );

  const [confirmRemove, setConfirmRemove] = useState<string | null>(null);
  const [fix, setFix] = useState<{ from: string; count: number } | null>(null);
  const [fixTo, setFixTo] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  const places = (n: number) => `${n} place${n === 1 ? "" : "s"}`;
  const official = new Set<string>(CAGAYAN_TOWNS);
  const describeTown = (t: string) =>
    [
      official.has(t) ? "official" : "not on the official list",
      inUse.get(t) ? places(inUse.get(t)!) : "",
    ]
      .filter(Boolean)
      .join(" · ");

  const add = (t: string) =>
    update((v) => ({ ...v, towns: normalizeTowns([...v.towns, t]) }));

  function remove(t: string) {
    update((v) => ({ ...v, towns: v.towns.filter((x) => x !== t) }));
    toast.toast({
      variant: "info",
      title: `${t} taken off the list`,
      description: "Save to keep the change.",
      action: { label: "Undo", onClick: () => add(t) },
    });
  }

  function openFix(from: string, count: number) {
    setFix({ from, count });
    // Start from the likeliest correction, so the common case is one click.
    setFixTo(suggest(from, [...new Set([...towns, ...CAGAYAN_TOWNS])])[0]?.value ?? null);
  }

  async function runFix() {
    if (!fix || !fixTo) return;
    setBusy(true);
    try {
      const n = await renameTown(fix.from, fixTo);
      if (!towns.includes(fixTo)) add(fixTo);
      toast.success(
        `${places(n)} now say ${fixTo}`,
        "Rebuild that town's offline bundle so phones get the spelling — the dashboard will list it.",
      );
      setFix(null);
      onDestinationsChanged();
    } catch (err) {
      toast.error(
        "That didn't work",
        err instanceof Error ? err.message : String(err),
      );
    } finally {
      setBusy(false);
    }
  }

  return (
    <Section
      title="Towns and municipalities"
      hint="The list offered for a destination's town. A town groups its offline bundle, so the spelling matters: pick from Cagayan's official towns rather than typing one."
      action={
        <button
          className="btn-quiet sm"
          onClick={() =>
            update((v) => ({ ...v, towns: normalizeTowns([...CAGAYAN_TOWNS]) }))
          }
        >
          Restore the official list
        </button>
      }
    >
      <div className="f wide">
        {!exists && (
          <p className="hint">
            Not saved yet — this is the built-in list the CMS has been using.
            Save to make it the province's.
          </p>
        )}
        {missing.length > 0 && (
          <Alert variant="warning" title="Places with a town that is not on the list">
            <ul>
              {missing.map((m) => (
                <li key={m.town}>
                  <strong>{m.town}</strong> — {places(m.count)}.{" "}
                  <button
                    className="link-button"
                    onClick={() => openFix(m.town, m.count)}
                  >
                    Fix the spelling on {m.count === 1 ? "it" : "them"}
                  </button>
                  {" or "}
                  <button className="link-button" onClick={() => add(m.town)}>
                    add it to the list
                  </button>
                </li>
              ))}
            </ul>
          </Alert>
        )}
        <div className="tag-row">
          {towns.map((t) => (
            <span key={t} className="badge">
              {t}
              {inUse.get(t) ? (
                <span className="chip-count">{inUse.get(t)}</span>
              ) : null}
              <button
                className="tag-x"
                aria-label={`Remove ${t}`}
                onClick={() =>
                  inUse.get(t) ? setConfirmRemove(t) : remove(t)
                }
              >
                ×
              </button>
            </span>
          ))}
          <SuggestInput
            label="Add a town"
            placeholder="Add a town"
            candidates={CAGAYAN_TOWNS}
            existing={towns}
            describe={describeTown}
            newWarning="not a Cagayan town"
            newByDefault={false}
            normalizeNew={capitalise}
            onPick={(t) => add(t)}
          />
        </div>
        <p className="hint">
          {towns.length} towns. The number on a town is how many places use it.
        </p>
      </div>

      <Dialog
        open={confirmRemove !== null}
        onDismiss={() => setConfirmRemove(null)}
        variant="warning"
        title={`Take ${confirmRemove ?? ""} off the list?`}
        actions={
          <>
            <button className="btn-quiet" onClick={() => setConfirmRemove(null)}>
              Keep it
            </button>
            <button
              className="btn-secondary"
              onClick={() => {
                if (confirmRemove) remove(confirmRemove);
                setConfirmRemove(null);
              }}
            >
              Take it off
            </button>
          </>
        }
      >
        {confirmRemove && places(inUse.get(confirmRemove) ?? 0)} use it. They
        keep it as their town — the list just stops offering it. If it is a
        misspelling, fix those places instead, from the warning above once it
        is off the list.
      </Dialog>

      <Dialog
        open={fix !== null}
        onDismiss={() => setFix(null)}
        variant="info"
        title={`Fix “${fix?.from ?? ""}”`}
        actions={
          <>
            <button className="btn-quiet" onClick={() => setFix(null)}>
              Cancel
            </button>
            <button
              className="btn-primary"
              disabled={busy || !fixTo || fixTo === fix?.from}
              onClick={() => void runFix()}
            >
              Change on {fix ? places(fix.count) : ""}
            </button>
          </>
        }
      >
        <div className="fix-town">
          <p>
            Change the town on {fix ? places(fix.count) : ""} from{" "}
            <strong>{fix?.from}</strong> to{" "}
            {fixTo ? <strong>{fixTo}</strong> : "…"}
          </p>
          <SuggestInput
            label="Change to"
            placeholder="Choose a different town"
            candidates={[...new Set([...CAGAYAN_TOWNS, ...towns])]}
            describe={describeTown}
            newWarning="not a Cagayan town"
            newByDefault={false}
            normalizeNew={capitalise}
            onPick={(t) => setFixTo(t)}
          />
        </div>
      </Dialog>
    </Section>
  );
}

/**
 * Finer kinds under the six fixed categories.
 *
 * The six stay fixed because the app draws a glyph and a colour for each. A
 * subcategory takes its category's, so the province can add one with no app
 * release. Adding is the same pick-first field as towns, against every
 * subcategory already named; taking one off that places use clears it from
 * them, after asking.
 */
function SubcategoriesSection({
  value,
  destinations,
  update,
  onDestinationsChanged,
}: {
  value: TaxonomySettings["subcategories"];
  destinations: Destination[] | null;
  update: TaxonomyUpdate;
  onDestinationsChanged: () => void;
}) {
  const toast = useToast();
  const usage = useMemo(
    () => subcategoryUsage(destinations ?? []),
    [destinations],
  );
  const everyName = useMemo(
    () => [...new Set(Object.values(value).flat())] as string[],
    [value],
  );
  const [confirm, setConfirm] = useState<
    { category: Category; name: string; count: number } | null
  >(null);
  const [busy, setBusy] = useState(false);

  const setList = (category: Category, fn: (list: string[]) => string[]) =>
    update((v) => ({
      ...v,
      subcategories: {
        ...v.subcategories,
        [category]: fn(v.subcategories[category] ?? []),
      },
    }));

  function remove(category: Category, name: string) {
    setList(category, (list) => list.filter((x) => x !== name));
    toast.toast({
      variant: "info",
      title: `${name} taken off ${CATEGORY_LABELS[category]}`,
      description: "Save to keep the change.",
      action: {
        label: "Undo",
        onClick: () =>
          setList(category, (list) => normalizeTowns([...list, name])),
      },
    });
  }

  async function removeInUse() {
    if (!confirm) return;
    setBusy(true);
    try {
      const n = await clearSubcategory(confirm.category, confirm.name);
      setList(confirm.category, (list) => list.filter((x) => x !== confirm.name));
      toast.success(
        `${confirm.name} taken off ${n} place${n === 1 ? "" : "s"}`,
        "Save to take it off the list too.",
      );
      setConfirm(null);
      onDestinationsChanged();
    } catch (err) {
      toast.error(
        "That didn't work",
        err instanceof Error ? err.message : String(err),
      );
    } finally {
      setBusy(false);
    }
  }

  return (
    <Section
      title="Categories and subcategories"
      hint="The six categories are fixed — the app draws a glyph and a colour for each. Add finer kinds under them; each takes its category's look, so it needs no app release."
    >
      <div className="f wide">
        <p className="hint">
          Name each the way one place is: “Waterfall”, not “Waterfalls” — the
          app reads it as “Waterfall in Peñablanca”.
        </p>
        <div className="subcats">
          {CATEGORIES.map((c) => (
            <div className="subcat-row" key={c}>
              <span className="subcat-name">{CATEGORY_LABELS[c]}</span>
              <div className="tag-row">
                {(value[c] ?? []).map((s) => {
                  const n = usage.get(`${c}/${s}`) ?? 0;
                  return (
                    <span key={s} className="badge">
                      {s}
                      {n ? <span className="chip-count">{n}</span> : null}
                      <button
                        className="tag-x"
                        aria-label={`Remove ${s} from ${CATEGORY_LABELS[c]}`}
                        onClick={() =>
                          n
                            ? setConfirm({ category: c, name: s, count: n })
                            : remove(c, s)
                        }
                      >
                        ×
                      </button>
                    </span>
                  );
                })}
                <SuggestInput
                  label={`Add a subcategory under ${CATEGORY_LABELS[c]}`}
                  placeholder="Add"
                  candidates={everyName}
                  existing={value[c] ?? []}
                  normalizeNew={capitalise}
                  onPick={(s) =>
                    setList(c, (list) => normalizeTowns([...list, s]))
                  }
                />
              </div>
            </div>
          ))}
        </div>
      </div>

      <Dialog
        open={confirm !== null}
        onDismiss={() => setConfirm(null)}
        variant="warning"
        title={`Take ${confirm?.name ?? ""} off ${
          confirm ? CATEGORY_LABELS[confirm.category] : ""
        }?`}
        actions={
          <>
            <button className="btn-quiet" onClick={() => setConfirm(null)}>
              Keep it
            </button>
            <button
              className="btn-secondary"
              disabled={busy}
              onClick={() => void removeInUse()}
            >
              Take it off {confirm?.count} place
              {confirm?.count === 1 ? "" : "s"}
            </button>
          </>
        }
      >
        {confirm?.count} place{confirm?.count === 1 ? " uses" : "s use"} it.
        It comes off them now, leaving them with just{" "}
        {confirm ? CATEGORY_LABELS[confirm.category] : ""}; anyone editing one
        of them is told.
      </Dialog>
    </Section>
  );
}

/**
 * Tags in use, with rename and remove across every destination.
 *
 * These act at once, outside the save bar: they rewrite destinations, not a
 * settings document, so there is nothing to hold as a draft. Each asks first.
 */
function TagsSection({
  destinations,
  onRetagged,
}: {
  destinations: Destination[] | null;
  onRetagged: () => void;
}) {
  const toast = useToast();
  const usage = useMemo(() => tagUsage(destinations ?? []), [destinations]);
  const [action, setAction] = useState<
    { kind: "rename" | "remove"; tag: string; count: number } | null
  >(null);
  const [to, setTo] = useState("");
  const [busy, setBusy] = useState(false);

  const target = to.trim().toLowerCase();
  const merges = usage.some((u) => u.tag === target && u.tag !== action?.tag);

  async function run() {
    if (!action) return;
    if (action.kind === "rename" && (!target || target === action.tag)) return;
    setBusy(true);
    try {
      const n = await retagDestinations(
        action.tag,
        action.kind === "remove" ? "" : target,
      );
      toast.success(
        action.kind === "remove"
          ? `“${action.tag}” removed`
          : merges
            ? `“${action.tag}” merged into “${target}”`
            : `“${action.tag}” renamed to “${target}”`,
        `${n} destination${n === 1 ? "" : "s"} updated.`,
      );
      setAction(null);
      refreshTagVocabulary();
      onRetagged();
    } catch (err) {
      toast.error(
        "That didn't work",
        err instanceof Error ? err.message : String(err),
      );
    } finally {
      setBusy(false);
    }
  }

  return (
    <Section
      title="Tags"
      hint="Every tag in use. Renaming onto a tag that already exists merges the two."
    >
      <div className="f wide">
        {destinations === null ? (
          <div className="skeleton" />
        ) : usage.length === 0 ? (
          <p className="hint">No destination has a tag yet.</p>
        ) : (
          <table className="data">
            <thead>
              <tr>
                <th>Tag</th>
                <th>Destinations</th>
                <th />
              </tr>
            </thead>
            <tbody>
              {usage.map((u) => (
                <tr key={u.tag}>
                  <td>
                    <span className="badge">{u.tag}</span>
                  </td>
                  <td>{u.count}</td>
                  <td className="row actions-cell">
                    <button
                      className="btn-quiet sm"
                      onClick={() => {
                        setTo(u.tag);
                        setAction({ kind: "rename", ...u });
                      }}
                    >
                      Rename
                    </button>
                    <button
                      className="btn-quiet sm danger"
                      onClick={() => setAction({ kind: "remove", ...u })}
                    >
                      Remove
                    </button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>

      <Dialog
        open={action !== null}
        onDismiss={() => setAction(null)}
        variant={action?.kind === "remove" ? "destructive" : "info"}
        title={
          action?.kind === "remove"
            ? `Remove “${action.tag}”?`
            : `Rename “${action?.tag ?? ""}”`
        }
        actions={
          <>
            <button className="btn-quiet" onClick={() => setAction(null)}>
              Cancel
            </button>
            <button
              className="btn-primary"
              disabled={
                busy ||
                (action?.kind === "rename" &&
                  (!target || target === action.tag))
              }
              onClick={() => void run()}
            >
              {`${action?.kind === "remove" ? "Remove from" : merges ? "Merge on" : "Rename on"} ${action?.count} place${action?.count === 1 ? "" : "s"}`}
            </button>
          </>
        }
      >
        {action?.kind === "remove" ? (
          <>
            It comes off {action.count} destination
            {action.count === 1 ? "" : "s"}. Anyone editing one of them is told
            before they save the old tag back.
          </>
        ) : (
          <div className="fgrid one">
            <Field
              label="New name"
              hint={
                merges
                  ? `“${target}” is already in use — the two will be merged.`
                  : "Tags are lowercase."
              }
            >
              <input
                autoFocus
                value={to}
                onChange={(e) => setTo(e.target.value)}
                onKeyDown={(e) => {
                  if (e.key === "Enter") void run();
                }}
              />
            </Field>
          </div>
        )}
      </Dialog>
    </Section>
  );
}

// ---- contact and notices ------------------------------------------------------

function AppTab({
  value,
  onChange,
}: {
  value: AppSettings;
  onChange: (v: AppSettings) => void;
}) {
  const contact = (key: keyof AppSettings["contact"]) => ({
    value: value.contact[key] ?? "",
    onChange: (e: React.ChangeEvent<HTMLInputElement>) =>
      onChange({ ...value, contact: { ...value.contact, [key]: e.target.value } }),
  });
  const setHotlines = (hotlines: AppSettings["hotlines"]) =>
    onChange({ ...value, hotlines });
  const a = value.announcement;
  const state = announcementState(a, Date.now());

  return (
    <>
      <Alert variant="info" title="Not in the app yet">
        These are saved for the Help and contact screen and the Explore notice
        planned in PLAN.md, Phase 5. Until those ship, visitors do not see them.
      </Alert>

      <Section
        title="Tourism office"
        hint="How a visitor reaches the province. All optional, shown as written."
      >
        <Field label="Office" wide>
          <input
            placeholder="Cagayan Provincial Tourism Office"
            {...contact("office")}
          />
        </Field>
        <Field label="Phone">
          <input placeholder="078 000 0000" {...contact("phone")} />
        </Field>
        <Field label="Email">
          <input placeholder="tourism@cagayan.gov.ph" {...contact("email")} />
        </Field>
        <Field label="Office hours">
          <input placeholder="Mon–Fri, 8:00am – 5:00pm" {...contact("hours")} />
        </Field>
        <Field label="Address">
          <input placeholder="Capitol Hills, Tuguegarao City" {...contact("address")} />
        </Field>
      </Section>

      <Section
        title="Emergency and help lines"
        hint="In the order the app lists them. Check every number: a wrong one here is worse than none."
        action={
          <button
            className="btn-secondary sm"
            onClick={() =>
              setHotlines([...value.hotlines, { label: "", number: "" }])
            }
          >
            <Plus size={16} aria-hidden="true" />
            Add a line
          </button>
        }
      >
        <div className="f wide">
          {value.hotlines.length === 0 ? (
            <p className="hint">No lines yet.</p>
          ) : (
            <ol className="hotlines">
              {value.hotlines.map((h, i) => (
                <li key={i} className="hotline">
                  <input
                    aria-label={`Line ${i + 1} name`}
                    placeholder="MDRRMO Peñablanca"
                    value={h.label}
                    onChange={(e) =>
                      setHotlines(
                        value.hotlines.map((x, j) =>
                          j === i ? { ...x, label: e.target.value } : x,
                        ),
                      )
                    }
                  />
                  <input
                    aria-label={`Line ${i + 1} number`}
                    placeholder="0917 000 0000"
                    inputMode="tel"
                    value={h.number}
                    onChange={(e) =>
                      setHotlines(
                        value.hotlines.map((x, j) =>
                          j === i ? { ...x, number: e.target.value } : x,
                        ),
                      )
                    }
                  />
                  <div className="segment-order">
                    <button
                      className="btn-quiet sm"
                      aria-label="Move up"
                      disabled={i === 0}
                      onClick={() => setHotlines(swap(value.hotlines, i, i - 1))}
                    >
                      <ArrowUp size={16} aria-hidden="true" />
                    </button>
                    <button
                      className="btn-quiet sm"
                      aria-label="Move down"
                      disabled={i === value.hotlines.length - 1}
                      onClick={() => setHotlines(swap(value.hotlines, i, i + 1))}
                    >
                      <ArrowDown size={16} aria-hidden="true" />
                    </button>
                    <button
                      className="btn-quiet sm"
                      aria-label={`Remove ${h.label || `line ${i + 1}`}`}
                      onClick={() =>
                        setHotlines(value.hotlines.filter((_, j) => j !== i))
                      }
                    >
                      <Trash2 size={16} aria-hidden="true" />
                    </button>
                  </div>
                </li>
              ))}
            </ol>
          )}
        </div>
      </Section>

      <Section
        title="Notice on Explore"
        hint="One short line across the top of Explore — a closure, a typhoon advisory. Leave it empty for none."
        action={
          a?.text ? (
            <button
              className="btn-quiet sm"
              onClick={() => onChange({ ...value, announcement: null })}
            >
              Remove the notice
            </button>
          ) : undefined
        }
      >
        <Field
          label="Notice"
          wide
          hint={`${a?.text.length ?? 0} / ${MAX_ANNOUNCEMENT}`}
        >
          <textarea
            rows={2}
            maxLength={MAX_ANNOUNCEMENT}
            placeholder="Callao Cave is closed on Monday 20 October for maintenance."
            value={a?.text ?? ""}
            onChange={(e) =>
              onChange({
                ...value,
                announcement: { text: e.target.value, until: a?.until ?? null },
              })
            }
          />
        </Field>
        <Field
          label="Show until"
          hint="Optional. It disappears after this day; leave empty to keep it until removed."
        >
          <input
            type="date"
            value={dateInputFromUntil(a?.until?.toDate())}
            onChange={(e) => {
              const until = untilFromDateInput(e.target.value);
              onChange({
                ...value,
                announcement: {
                  text: a?.text ?? "",
                  until: until ? toTimestamp(until) : null,
                },
              });
            }}
          />
        </Field>
        <div className="f">
          <label>In the app</label>
          <span
            className={
              state === "live"
                ? "badge ok"
                : state === "ended"
                  ? "badge warn"
                  : "badge draft"
            }
          >
            {state === "live"
              ? "Showing"
              : state === "ended"
                ? "Ended — not shown"
                : "No notice"}
          </span>
        </div>
      </Section>
    </>
  );
}

function swap<T>(list: T[], i: number, j: number): T[] {
  const out = [...list];
  [out[i], out[j]] = [out[j], out[i]];
  return out;
}

// ---- policies -----------------------------------------------------------------

function PoliciesTab({
  value,
  onChange,
}: {
  value: PolicySettings;
  onChange: (v: PolicySettings) => void;
}) {
  return (
    <>
      <Alert variant="info" title="Not in the app yet">
        Saved for the Profile screens planned in PLAN.md, Phase 5. The Play
        Store needs a privacy policy before release, since the app signs people
        in and collects analytics — write it here, and the app will show it.
      </Alert>
      <PolicySection
        title="Privacy policy"
        text={value.privacy}
        updatedAt={value.privacyUpdatedAt}
        onText={(privacy) => onChange({ ...value, privacy })}
      />
      <PolicySection
        title="Terms of use"
        text={value.terms}
        updatedAt={value.termsUpdatedAt}
        onText={(terms) => onChange({ ...value, terms })}
      />
    </>
  );
}

function PolicySection({
  title,
  text,
  updatedAt,
  onText,
}: {
  title: string;
  text: string;
  updatedAt?: Timestamp | null;
  onText: (t: string) => void;
}) {
  return (
    <Section
      title={title}
      hint={
        updatedAt
          ? `Readers are told it was last updated on ${formatDate(updatedAt)}. That date moves when this text changes, not when the other policy does.`
          : "Not written yet."
      }
    >
      <Field
        label="Text"
        wide
        hint="Plain text, shown as written. Leave a blank line between paragraphs."
      >
        <textarea
          aria-label={title}
          className="policy-text"
          rows={16}
          value={text}
          onChange={(e) => onText(e.target.value)}
        />
      </Field>
    </Section>
  );
}
