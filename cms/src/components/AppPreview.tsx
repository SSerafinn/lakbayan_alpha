import { useLayoutEffect, useRef, useState } from "react";
import type { Category, Destination } from "../types/destination";
import { placeTags, type PlaceTag } from "../types/preview";
import { useImageUrl } from "./useImageUrl";

type Draft = Omit<Destination, "id">;
type View = "photo" | "featured" | "page";

/**
 * A place as the app will draw it, beside the fields that make it.
 *
 * The description field said "Shown on cards", and nobody editing it could
 * see a card. This draws the three a visitor meets, in the app's own colours,
 * type and glyphs (`--lk-app-*`, Phosphor), from the draft as it is typed:
 *
 * - **Photo**: the place in Browse, search and its town's page.
 * - **Featured**: the front of Explore's deck, while Featured is on.
 * - **Page**: the top of the place's own page, where the description leads.
 *
 * What a photo says follows the app's own rule, ported in `types/preview.ts`.
 * A preview that drifted from the app would be worse than none, so it draws
 * only what those rules decide and nothing the app does not.
 */
export function AppPreview({ draft, hasAR }: { draft: Draft; hasAR: boolean }) {
  const [chosen, setChosen] = useState<View>("photo");
  // Featured is a view only while the place is featured.
  const view: View = chosen === "featured" && !draft.featured ? "photo" : chosen;
  const views: { id: View; label: string }[] = [
    { id: "photo", label: "Photo" },
    ...(draft.featured ? [{ id: "featured" as const, label: "Featured" }] : []),
    { id: "page", label: "Page" },
  ];

  return (
    <div className="app-preview">
      <div className="ap-switch" role="tablist" aria-label="Where it appears">
        {views.map((v) => (
          <button
            key={v.id}
            role="tab"
            aria-selected={view === v.id}
            className={view === v.id ? "on" : undefined}
            onClick={() => setChosen(v.id)}
          >
            {v.label}
          </button>
        ))}
      </div>

      <div className="ap-stage" role="tabpanel">
        {view === "photo" && <PhotoTile draft={draft} hasAR={hasAR} />}
        {view === "featured" && <FeaturedFace draft={draft} hasAR={hasAR} />}
        {view === "page" && <PageTop draft={draft} />}
      </div>

      <p className="hint">
        {view === "photo"
          ? "In Browse, search and its town's page."
          : view === "featured"
            ? "The front of Explore's deck, while Featured is on."
            : "The top of the place's own page."}
      </p>
    </div>
  );
}

/** A Phosphor glyph, from the app's own bundled font. */
const GLYPH = {
  scan: { code: 0xebb6, fill: false },
  popular: { code: 0xe242, fill: true },
  heart: { code: 0xe2a8, fill: false },
} as const;

/** `AppIcons.kind`: the same codepoint in both weights. */
const KIND_GLYPH: Record<Category, number> = {
  nature: 0xe7ae,
  food: 0xe262,
  church: 0xecea,
  heritage: 0xe9d0,
  museum: 0xe0b4,
  landmark: 0xe244,
};

function Glyph({ code, fill = false }: { code: number; fill?: boolean }) {
  return (
    <span className={fill ? "ap-glyph fill" : "ap-glyph"} aria-hidden="true">
      {String.fromCodePoint(code)}
    </span>
  );
}

/** The cover, or the app's placeholder grey when there is none yet. */
function Cover({ path }: { path: string | undefined }) {
  const url = useImageUrl(path);
  if (!path) return <div className="ap-cover empty">No photo yet</div>;
  if (url === "failed") return <div className="ap-cover empty">Photo unavailable</div>;
  if (!url) return <div className="ap-cover" />;
  return <img className="ap-cover" src={url} alt="" />;
}

function Pills({ tags }: { tags: PlaceTag[] }) {
  if (tags.length === 0) return null;
  return (
    <span className="ap-pills">
      {tags.map((t) =>
        t.kind === "price" ? (
          <span key="price" className="ap-pill">
            {t.label}
          </span>
        ) : (
          <span key={t.kind} className="ap-pill round" title={t.kind === "scan" ? "Exhibits to scan" : "Popular"}>
            <Glyph {...GLYPH[t.kind]} />
          </span>
        ),
      )}
    </span>
  );
}

/** Words the app would draw, or a quiet stand-in while the field is empty. */
function Words({ value, empty }: { value: string; empty: string }) {
  return value.trim() ? <>{value}</> : <span className="ap-empty">{empty}</span>;
}

/** A town page's wide photo (`PlacePhoto`, 15:8, the heart, two tags). */
function PhotoTile({ draft, hasAR }: { draft: Draft; hasAR: boolean }) {
  return (
    <div className="ap-photo" style={{ aspectRatio: "15 / 8" }}>
      <Cover path={draft.images[0]} />
      <div className="ap-top">
        <Pills tags={placeTags(draft, hasAR)} />
        <span className="ap-heart">
          <Glyph {...GLYPH.heart} />
        </span>
      </div>
      <div className="ap-scrim">
        <p className="ap-title-large">
          <Words value={draft.name} empty="Name" />
        </p>
        <p className="ap-label">
          <Words value={draft.town} empty="Town" />
        </p>
      </div>
    </div>
  );
}

/** The front of Explore's deck (`FeaturedDeck`, 5:6): why it is there, the heart, then on the scrim its tags, name and town. */
function FeaturedFace({ draft, hasAR }: { draft: Draft; hasAR: boolean }) {
  return (
    <div className="ap-photo featured" style={{ aspectRatio: "5 / 6" }}>
      <Cover path={draft.images[0]} />
      <div className="ap-top">
        <span className="ap-pill">
          <Glyph {...GLYPH.popular} />
          Popular This Season
        </span>
        <span className="ap-heart large">
          <Glyph {...GLYPH.heart} />
        </span>
      </div>
      <div className="ap-scrim">
        {/* The tag above says popular already. */}
        <Pills tags={placeTags(draft, hasAR, { hide: ["popular"] })} />
        <p className="ap-display">
          <Words value={draft.name} empty="Name" />
        </p>
        <p className="ap-label">
          <Words value={draft.town} empty="Town" />
        </p>
      </div>
    </div>
  );
}

/**
 * The top of the place's page: the photo, the name with its kind as glyphs,
 * and the description leading the history, cut at three lines with Read More.
 */
function PageTop({ draft }: { draft: Draft }) {
  const lead = draft.description.trim();
  const rest = draft.history?.trim() ?? "";
  const about = useRef<HTMLParagraphElement>(null);
  const [long, setLong] = useState(false);

  // Read More only when the text is cut, as the app measures it.
  useLayoutEffect(() => {
    const el = about.current;
    setLong(el !== null && el.scrollHeight > el.clientHeight + 1);
  }, [lead, rest]);

  return (
    <div className="ap-page">
      <div className="ap-photo stage" style={{ aspectRatio: "7 / 5" }}>
        <Cover path={draft.images[0]} />
        {draft.images.length > 1 && (
          <span className="ap-dots" aria-hidden="true">
            {draft.images.slice(0, 7).map((p, i) => (
              <i key={p} className={i === 0 ? "on" : undefined} />
            ))}
          </span>
        )}
      </div>
      <div className="ap-page-body">
        <div className="ap-page-title">
          <p className="ap-hero">
            <Words value={draft.name} empty="Name" />
          </p>
          <span className="ap-facts">
            <span className="ap-fact" title={draft.subcategory || draft.category}>
              <Glyph code={KIND_GLYPH[draft.category]} />
            </span>
            {draft.popular && (
              <span className="ap-fact" title="Popular">
                <Glyph {...GLYPH.popular} />
              </span>
            )}
          </span>
        </div>
        {lead || rest ? (
          <>
            <p ref={about} className="ap-about">
              {lead && <strong>{lead}</strong>}
              {lead && rest && " "}
              {rest}
            </p>
            {long && <span className="ap-more">Read More</span>}
          </>
        ) : (
          <p className="ap-about">
            <span className="ap-empty">The short description leads here.</span>
          </p>
        )}
      </div>
    </div>
  );
}
