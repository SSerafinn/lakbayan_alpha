# Data model (Firestore) — the FE↔BE contract

Change collection shapes only alongside `firestore.rules`, `firestore.indexes.json`,
and a `schemaVersion` bump. Use the `add-collection` skill.

```
destinations/{id}                                              // schemaVersion 5
  name          string    required
  slug          string    required   // auto from name; used in deep links
  town          string    required   // municipality, e.g. "Peñablanca"
  category      string    required   // one of the six (enum below), or the id
                                     // of a category added in settings/taxonomy
  subcategory   string?              // finer kind within `category`, e.g. "Waterfall"
                                     // under nature; one of settings/taxonomy's
                                     // list for that category, or null
  description   string    required   // card + detail intro, max 140 chars
  history       string?              // long-form; detail screen only
  coords        map       required   // { lat: number, lng: number }
  images        string[]             // Storage paths, first is the card image
  imageCredits  map?                 // { [Storage path]: { credit?, licence? } }, v5 —
                                     // who to credit for a photo in `images`, and
                                     // under what licence or permission; both free
                                     // text. Keyed by the path exactly as it is in
                                     // `images`; a key not in `images` is stale and
                                     // readers ignore it. See "Changes in v5".
  popular       bool      default false   // "Popular Places" rail
  featured      bool      default false   // drives the FEATURED badge
  nearbyEligible bool     default true    // may appear in others' "Nearby"
  offlineEligible bool    default true    // include in town offline bundles
  isMuseum      bool      default false   // gates the AR tab in the CMS
  hasAR         bool      default false   // drives the AR badge; the CMS keeps it
                                          // true exactly when a museum has an
                                          // exhibit (D-18)
  tags          string[]             // free-form, e.g. ["caves","river"]
  practical     map?                 // all optional free text, see below
  status        string    required   // draft | published
  schemaVersion number    required
  createdAt, updatedAt                // serverTimestamp
  updatedBy     string?              // uid of the last editor, for the CMS list

  practical: { entryFee?, openHours?, bestSeason?, accessibility? }  // strings

destinations/{id}/segments/{sid}                               // audio guide stops
  title         string    required
  description   string?
  audioUrl      string?              // Storage path; when null, narrate ttsText
  ttsText       string?              // flutter_tts fallback
  order         number    required   // 1-based, defines player sequence
  // No status field: visibility is inherited from the parent destination in
  // firestore.rules. Adding one here would let the two drift apart.
  //
  // `order` is written from list position by the CMS editor and is contiguous
  // from 1. Readers should still sort by it rather than assume the gap-free
  // sequence — a document written by hand or by a script need not honour it.

destinations/{id}/exhibits/{eid}                               // AR exhibits (D-18), v4
  title         string    required   // "The Callao Man replica"
  description   string?              // one line, on the card when it is recognised
  story         string?              // the exhibit sheet; blank lines split paragraphs
  markerPath    string    required   // Storage path of the image the camera matches:
                                     //   /ar/{destId}/markers/{eid}-{timestamp}.{ext}
  markerWidthM  number    required   // the marker's real width in metres — ARCore
                                     // tracks sooner and steadier knowing it
  audioUrl      string?              // Storage path, recorded narration
  ttsText       string?              // spoken when there is no recording
  order         number    required   // 1-based; the no-camera list's sequence
  // No status field, as with segments: visibility follows the parent
  // destination in firestore.rules. Only meaningful under `isMuseum`.
offlineBundles/{townId}                          // written only by a function
  name          string    required   // the town's display name, exactly
  destinationIds string[] required   // published + offlineEligible, sorted
  tilePackRef   string    required   // tiles/{townId}/pack.pmtiles
  size          number    required   // total bytes: assets + map pack
  version       string    required   // content fingerprint; see below
  status        string    required   // pending | ready  (never `stale` — below)
  generatedAt              // serverTimestamp
  // No asset list. A client already reads the destinations, their segments
  // and their exhibits, so the image, audio and AR marker paths are derivable;
  // storing them twice would let the two drift.
tours/{id}                        // id is slugify(title) — see below
  title         string    required
  description   string?
  stops         string[]  required   // destination ids, in visiting order
  coverImg      string?              // Storage path
  featured      bool      default false
  createdAt, updatedAt                // serverTimestamp
  updatedBy     string?              // uid of the last editor (CMS, since 2026-10)
  // No status field. `allow read: if true` below means a tour is public the
  // moment the document exists, so there is no draft state to stage one in —
  // the CMS refuses to save a tour that is not fit to be read instead.
guides/{id}                                                    // real people — see below
  name          string    required
  town          string    required   // municipality
  specialties   string[]             // lowercase, e.g. ["caving","birdwatching"]
  contact       string    required   // free text: phone, email, or both
  verified      bool      default false   // accredited by the province
  featured      bool      default false
  createdAt, updatedAt                // serverTimestamp
  updatedBy     string?              // uid of the last editor (CMS, since 2026-10)
  // No status field, deliberately. Unlike destinations there is no draft
  // state: the rule below exposes a guide to every signed-in user the moment
  // the document exists, so "saved but not live" is not a state this
  // collection can represent. Removing someone is a hard delete.
users/{uid}                                                    // no role field — see below
  uid, email, displayName, photoUrl,                           // identity, refreshed each sign-in
  savedTourIds[], downloadedTownIds[],                         // denormalized for offline reads
  createdAt, updatedAt                                         // serverTimestamp
  // Readable by the owner and by admins (the CMS Users screen); writable by
  // the owner only. An admin cannot edit someone else's profile.

users/{uid}/itineraries/{id}                  // tours somebody built themselves
  name          string    required   // what they called it
  destinationIds string[] required   // ordered; the order IS the route
  startDate     timestamp?           // when the trip runs. Both optional and
  endDate       timestamp?           // independently clearable — a plan can
                                     // exist long before it has dates.
  createdAt, updatedAt                // serverTimestamp
  // Owner-only in both directions — not admin-readable, unlike the parent.
  // These are private plans; the CMS has no business in them.
  //
  // The rule is `allow read, write: if isOwner(uid)` with no field validation,
  // so nothing rejects a document that does not match this block. That is a
  // deliberate trade — a private subcollection nobody else can read does not
  // earn the cost of a per-field rule — but it does mean this list is kept by
  // hand. `startDate`/`endDate` reached Firestore before they reached here.

settings/{taxonomy | app | policies}           // schemaVersion 2 — province-wide, CMS screen 11
  // Three fixed documents, not one: the app reads `app` at startup and has no
  // reason to pull pages of policy text with it, and each is saved (and
  // version-checked) on its own. Rules allow exactly these three ids.
  // Readable by anyone — the privacy policy must be reachable before sign-in,
  // and hotlines are worth caching for offline use. Written by admins only.
  // The app watches `app` from Explore on every launch (the notice), which is
  // what puts the hotlines in Firestore's cache for Help offline; `policies`
  // is read when Profile opens one. A document absent from the cache while
  // offline is "not loaded yet", not "unwritten" (SettingsRepository).
  // Every document also carries schemaVersion, updatedAt, updatedBy.

  taxonomy:
    towns       string[]  required   // the municipality list the CMS offers for
                                     // `town`; display names exactly as written
                                     // on destinations, since `town` groups
                                     // offline bundles.
    categories  list?                // categories beyond the six, in the order
                                     // added: [{ id, name, plural, glyph, look }].
                                     // `id` is a slug of the first name and never
                                     // changes (destinations store it); `name` is
                                     // one place ("Resort"), `plural` the chip
                                     // ("Resorts"); `glyph` is a name from
                                     // design/category-glyphs.json; `look` is one
                                     // of the six, whose colours it takes. So the
                                     // app draws a new one with no release. The
                                     // CMS refuses to remove one a place uses.
    subcategories map?               // { [category id]: string[] } — finer kinds the
                                     // province adds under any category.
                                     // They borrow their category's glyph and
                                     // colour, so adding one needs no release.
  app:
    contact     map?                 // { office?, phone?, email?, hours?, address? }, free text
    hotlines    list                 // [{ label, number }], in display order
    announcement map?                // { text, until? } — a notice at the top of
                                     // Explore; null or absent when there is none.
                                     // `until` is a timestamp; past it, readers
                                     // treat the notice as gone.
  policies:
    privacy     string               // plain text, shown as written; blank lines
    terms       string               //   separate paragraphs
    privacyUpdatedAt timestamp?      // when each text last changed — the
    termsUpdatedAt   timestamp?      //   "last updated" date a reader is shown
```

**`updatedAt` doubles as the version for the CMS's save check.** An editor
remembers the value it loaded and saves through a transaction that refuses if
the stored value has moved on, so two admins cannot silently overwrite each
other (`cms/src/lib/versioned.ts`). Anything that writes these collections must
keep setting `updatedAt` on every write — a write that skips it is invisible to
the check. `updatedBy` is optional and only names who made a conflicting
change; tours and guides written before 2026-10, or by the importer, have none.

`users/{uid}` is implemented as `UserProfile`
(`lib/features/auth/domain/user_profile.dart`, freezed + json_serializable) and
written by `UserProfileRepository.ensureProfile` on sign-in. That method takes
distinct create and update paths rather than a blind `set(merge: true)`, because
`firestore.rules` gates the two separately and `createdAt` must not be rewritten
on every login.

**Admin rights are a custom auth claim (`request.auth.token.admin`), not a Firestore
field.** The `setAdminRole` callable in `functions/` sets it, from the CMS Users
screen; `scripts/grant-admin.mjs` bootstraps the very first admin. Rules never
read a `role` document, so admin checks cost no extra read and `firestore.rules`
/ `storage.rules` stay consistent. Writing a `role` field from a client is
rejected outright. Because the claim lives on the Auth account, the set of
admins and the set of `users/` documents are different lists — see D-12.

Enums: `category` = church | nature | heritage | museum | food | landmark, or an
added category's `id` (settings/taxonomy `categories`). A client that cannot
place one shows it as Other.

**A tour's document id is `slugify(title)`, not a random one.** Destinations get
random ids and carry a `slug` field; tours put the slug in the id instead, and
both the CMS and `scripts/import-content.mjs` derive it the same way. That is
what makes an import of a tour the CMS already has an update rather than a
duplicate. Renaming a tour does **not** re-key it — the id keeps the original
title's slug, which is the price of not orphaning anything that already points
at it.

### Two kinds of tour, in two places

`tours/{id}` is the province's own: admin-written, world-readable, and part of
the catalog. `users/{uid}/itineraries/{id}` is one a visitor built for
themselves. They are deliberately **not** the same collection, because
`firestore.rules` gates `tours` on the `admin` claim — a visitor could not write
one, and relaxing that rule to let them would open the province's catalog to
anybody with an account.

The app treats them alike where it can. Both are an ordered list of destination
ids, so the map draws a route from either without caring which it has. Saving a
province tour is a different act again: it records the id in `savedTourIds` on
the user document rather than copying the tour, so an itinerary the province
later edits stays correct.

**`guides` is the one content collection that is not world-readable.** Every row
is a real person's contact details, so `firestore.rules` requires sign-in to
read it — the others allow anonymous reads of published content. Two consequences
worth keeping in mind when extending it: there is no draft state to stage an
entry in, and consent to be listed is **not** modelled here. The intake sheet
records who obtained it and when (`docs/data-intake/04-local-guides.csv`), and
`scripts/import-content.mjs` refuses to import a guide without it, but nothing in
Firestore carries that fact. If the province ever needs to prove consent from the
system rather than from a spreadsheet, that is a schema change.

**schemaVersion 5** (destinations). Bump it here and in
`destinationSchemaVersion` together with any shape change, so a client reading a
cached document written by an older build can tell.

### Changes in v5 (2026-11-18)

Added `imageCredits`, optional: a photo's credit and licence, for the Wikimedia
Commons photos the first wave published under CC BY and CC BY-SA, which must
credit the photographer wherever the photo is shown
(`docs/data-intake/first-wave-photos.md` is the record of each).

**A map keyed by path, beside `images`, not a change to `images`.** Turning
`images` into a list of objects would break every client already reading it as
strings, and a second list in step with the first drifts the moment one is
reordered (Make cover) and the other is not. Keyed by the path, a credit
follows its photo through any reorder, and an older build simply ignores the
field. The cost is that a key can outlive its photo; the CMS drops those on
save and readers only ever look up a path that is in `images`.

Firestore map keys may hold `/` and `.`, so the path is the key as it is. Write
the map as a whole value (`imageCredits: {...}`); never address one entry with a
dotted field path such as `imageCredits.destinations/x/images/1.webp`, where
the dots would be read as nesting.

- `credit`: who to name: the photographer as the licence asks ("Patrickroque01"),
  or the owner ("Cagayan Provincial Tourism Office").
- `licence`: the licence ("CC BY-SA 4.0") or, for a photo used by permission,
  how it was cleared ("Province-owned; approved for the app").

**The app shows `licence` only when it names a public licence**: Creative
Commons (`CC …`, `CC0`, `Creative Commons …`) or public domain. A permission
note is a record of how a photo was cleared, not a notice for a visitor, so a
province photo reads "Photo: Cagayan Provincial Tourism Office" and a Commons one
"Photo: Patrickroque01 / CC BY-SA 4.0". The rule is implemented twice, in the
app (`photo_credit.dart`) and the CMS (`types/photo-credit.ts`, for its preview
of that line), and both assert `cms/src/types/photo-credit-cases.json`.

`firestore.rules` is unchanged: destinations are admin-written with no
per-field validation, and the field is as public as the photos it credits.
`scripts/import-content.mjs` writes it from sheet 5's `photographer_or_credit`
and `licence_or_permission` columns.

### Settings v2 (2026-11-18)

`settings/taxonomy` gains `categories`: categories the province adds beyond the
six, each with an icon from a fixed list (`design/category-glyphs.json`, shared
by the CMS and the app) and the colours of one of the six. A destination's
`category` may now hold one of their ids. The destination document's shape is
unchanged, so this did not bump its schemaVersion (4 then; v5 is `imageCredits`,
above); clients older than this read an added
category as `unknown` (Other), as they always have for values they do not know.

### Changes in v4 (2026-10-21)

Added the `exhibits` subcollection for the AR pilot (D-18). The destination
document itself is unchanged; the bump marks that a museum's content now has a
second subcollection, which the offline bundle covers (its markers and
narration download with the town, so scanning works with no signal). `hasAR`
becomes derived: the CMS sets it when a museum has at least one exhibit, rather
than leaving it a switch that can claim AR nobody built.

### Changes in v3 (2026-10-12)

Added `subcategory`, optional. The six categories stay fixed — the app draws a
glyph and a colour for each — and the province now adds finer kinds under them
in Settings, which inherit their category's look. An older build ignores the
field; nothing else about the document changed. `scripts/import-content.mjs`
merges into destinations, so a re-import keeps a subcategory set in the CMS.

### Changes in v2 (2026-08-04)

Driven by the admin wireframe's Destination Editor, which needed fields the
scaffold schema never had. Added: `slug`, `tags`, `practical`, `offlineEligible`,
`isMuseum`, `updatedBy`, and `landmark` as a category.

Two deliberate calls:

- **`nearby: string[]` became `nearbyEligible: bool`.** The wireframe offers a
  toggle — "Eligible for Nearby Places" — not a curated list. Nearby is computed
  by distance from `coords`, so a hand-maintained array of ids would be a second
  mechanism that immediately drifts from the first.
- **`practical.openHours` is free text**, not structured hours. It closes the
  "Open now" gap enough to display, but *cannot* be computed against — a real
  open/closed badge needs structured per-day hours, which is a content-model
  decision nobody has made. Until then the app should render the string, not a
  live status.

### Storage paths

```
/destinations/{id}/images/{timestamp}.{ext}        // uploaded via the CMS
/destinations/{id}/images/{source-filename}.{ext}  // written by the importer
/destinations/{id}/audio/{segmentId}.{ext}
/tours/{id}/cover-{timestamp}.{ext}               // uploaded via the CMS
/tours/{id}/cover.{ext}                           // written by the importer
/ar/{destId}/markers/{exhibitId}-{timestamp}.{ext} // AR markers (D-18), via the CMS
/tiles/{townId}/pack.pmtiles
```

**`storage.rules` enumerates these paths one by one and denies everything else**,
so a new asset location needs a rule added there before an upload will work. A
tour cover written to any other path is rejected, not silently accepted.

**What an upload may be.** Every object here is public and ends up in the
offline download a tourist pulls over mobile data, so the rules cap it:

| Path | Types | Max |
|---|---|---|
| images, tour covers, AR markers | `image/jpeg`, `image/png`, `image/webp` | 3 MB |
| audio | `audio/mpeg`, `mp4`, `aac`, `wav`, `ogg` | 50 MB |
| tiles | not checked — built by `scripts/extract-tiles.mjs`, not the CMS | — |

The caps are a backstop. The CMS resizes every photo before it uploads
(`cms/src/lib/image.ts`): it is scaled to fit 2000 px and re-encoded as WebP
(JPEG where the browser cannot write WebP), which also strips the camera's
metadata, location included. A phone photo of 4–10 MB arrives as a few hundred
KB, which is why a CMS-uploaded image is usually `.webp`. The type check
matters as much as the size: an object served from a public bucket as
`text/html` or `image/svg+xml` is a web page anyone can be sent to. The numbers
live in `cms/src/types/media.ts` as well; change both together.

**Images have two naming conventions on purpose.** The CMS uses a timestamp so
that deleting one photo never renumbers the survivors, and so that a
replacement never lands on the path the saved document still points at: a
photo, cover or AR marker the CMS takes off is deleted only after the save
that drops it, so Cancel and Discard leave the old one intact.
`scripts/import-content.mjs` replaces a destination's whole set in one go and
has no such problem; what it needs instead is a name that is stable across
runs, because a fresh timestamp each time would strand every object the
previous import uploaded. Readers only ever follow the path stored on the
document, so the two coexist safely.

**Audio is one object per segment or exhibit, named after it** — exhibit
narration shares `/destinations/{id}/audio/`, since exhibit and segment ids are
both Firestore auto-ids and cannot collide. The extension is whatever
was uploaded (mp3, m4a, aac, wav, ogg) rather than a fixed `.mp3` — that suffix
on an m4a file misleads everything downstream that sniffs by name. Replacing a
recording with a different format therefore writes a new object, and both the
CMS and the importer delete the one it replaced.

Segment ids are random when the CMS creates them and `stop-01`, `stop-02` … when
the importer does, which is what keeps `{segmentId}.{ext}` stable across
re-imports.

Denormalize for offline read patterns (a bundle carries what a town needs).

### `offlineBundles` is written by a Cloud Function, never by a client

`generateOfflineBundle(town)` in `functions/` builds it. Deciding whether a
bundle is ready means statting every object in Storage, which a browser should
neither be trusted to do nor made to wait for. The CMS triggers it from screen
7 and reads the result; the app only ever reads.

**`version` is a fingerprint of the content, not a counter.** It is a short hash
of the destination ids and their `updatedAt`, so editing, adding or removing a
place moves it and regenerating an unchanged town does not. That second half
matters as much as the first: a version that changed on every build would send
every phone off to re-download a town it already has.

It deliberately does **not** cover the map pack. A pack is rendered by
`tools/tiles` and uploaded once; replacing one is a deliberate act, and the
person doing it should rebuild the bundle to move the version.

**`stale` is a phone-side verdict, not a stored value.** The function only ever
writes `pending` or `ready`. A client concludes "stale" by comparing the version
it downloaded against the one in this document — which is also how the CMS's
*Check* button reports it, by running the function in dry-run mode and comparing
the version it would produce.
