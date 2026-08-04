# Data model (Firestore) — the FE↔BE contract

Change collection shapes only alongside `firestore.rules`, `firestore.indexes.json`,
and a `schemaVersion` bump. Use the `add-collection` skill.

```
destinations/{id}                                              // schemaVersion 1
  name          string    required
  town          string    required   // municipality, e.g. "Peñablanca"
  category      string    required   // enum below
  description   string    required   // one or two sentences; card + detail intro
  history       string?              // long-form; detail screen only
  coords        map       required   // { lat: number, lng: number }
  images        string[]             // Storage paths, first is the card image
  popular       bool      default false
  featured      bool      default false   // drives the FEATURED badge
  nearby        string[]             // destination ids, for "Nearby stops"
  hasAR         bool      default false   // drives the AR badge
  status        string    required   // draft | published
  schemaVersion number    required
  createdAt, updatedAt                // serverTimestamp

destinations/{id}/segments/{sid}                               // audio guide stops
  title         string    required
  description   string?
  audioUrl      string?              // Storage path; when null, narrate ttsText
  ttsText       string?              // flutter_tts fallback
  order         number    required   // 1-based, defines player sequence
  // No status field: visibility is inherited from the parent destination in
  // firestore.rules. Adding one here would let the two drift apart.
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

Enums: `category` = church | nature | heritage | museum | food.

**schemaVersion 1** (destinations, segments, users). Bump it here and in
`Destination.schemaVersion` together with any shape change, so a client reading a
cached document written by an older build can tell.

> **Known gap.** The design system's destination card renders an "Open now" badge,
> but nothing in this schema carries opening hours. Either add an `hours` field
> when the content track defines its shape, or drop the badge. Right now
> `DestinationCard.status` is caller-supplied and no query can populate it.
Storage paths: `/destinations/{id}/images/{n}.jpg`, `/destinations/{id}/audio/{segmentId}.mp3`,
`/ar/{destId}/markers/{n}.jpg`, `/tiles/{townId}/pack.mbtiles`.

Denormalize for offline read patterns (a bundle carries what a town needs).
