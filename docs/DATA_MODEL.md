# Data model (Firestore) — the FE↔BE contract

Change collection shapes only alongside `firestore.rules`, `firestore.indexes.json`,
and a `schemaVersion` bump. Use the `add-collection` skill.

```
destinations/{id}                                              // schemaVersion 2
  name          string    required
  slug          string    required   // auto from name; used in deep links
  town          string    required   // municipality, e.g. "Peñablanca"
  category      string    required   // enum below
  description   string    required   // card + detail intro, max 140 chars
  history       string?              // long-form; detail screen only
  coords        map       required   // { lat: number, lng: number }
  images        string[]             // Storage paths, first is the card image
  popular       bool      default false   // "Popular Places" rail
  featured      bool      default false   // drives the FEATURED badge
  nearbyEligible bool     default true    // may appear in others' "Nearby"
  offlineEligible bool    default true    // include in town offline bundles
  isMuseum      bool      default false   // gates the AR tab in the CMS
  hasAR         bool      default false   // drives the AR badge
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
offlineBundles/{townId}
  name, destinationIds[], tilePackRef, size, version, status   // pending | ready | stale
tours/{id}
  title, description, stops[] -> destId, coverImg, featured
guides/{id}
  name, town, specialties[], contact, verified, featured
users/{uid}                                                    // no role field — see below
  uid, email, displayName, photoUrl,                           // identity, refreshed each sign-in
  savedTourIds[], downloadedTownIds[],                         // denormalized for offline reads
  createdAt, updatedAt                                         // serverTimestamp
```

`users/{uid}` is implemented as `UserProfile`
(`lib/features/auth/domain/user_profile.dart`, freezed + json_serializable) and
written by `UserProfileRepository.ensureProfile` on sign-in. That method takes
distinct create and update paths rather than a blind `set(merge: true)`, because
`firestore.rules` gates the two separately and `createdAt` must not be rewritten
on every login.

**Admin rights are a custom auth claim (`request.auth.token.admin`), not a Firestore
field.** A trusted Cloud Function sets it. Rules never read a `role` document, so
admin checks cost no extra read and `firestore.rules` / `storage.rules` stay
consistent. Writing a `role` field from a client is rejected outright.

Enums: `category` = church | nature | heritage | museum | food | landmark.

**schemaVersion 2** (destinations). Bump it here and in
`destinationSchemaVersion` together with any shape change, so a client reading a
cached document written by an older build can tell.

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
Storage paths: `/destinations/{id}/images/{timestamp}.{ext}`,
`/destinations/{id}/audio/{segmentId}.{ext}` — one object per segment, named
after it. The extension is whatever was uploaded (mp3, m4a, aac, wav, ogg)
rather than a fixed `.mp3`: that suffix on an m4a file misleads everything
downstream that sniffs by name. Replacing a recording with a different format
therefore writes a new object, and the CMS deletes the old one,
`/ar/{destId}/markers/{n}.jpg`, `/tiles/{townId}/pack.mbtiles`.

Denormalize for offline read patterns (a bundle carries what a town needs).
