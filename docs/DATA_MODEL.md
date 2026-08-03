# Data model (Firestore) — the FE↔BE contract

Change collection shapes only alongside `firestore.rules`, `firestore.indexes.json`,
and a `schemaVersion` bump. Use the `add-collection` skill.

```
destinations/{id}
  name, town, category, description, history,
  coords {lat,lng}, images[], popular, nearby, hasAR, status   // draft | published
destinations/{id}/segments/{sid}
  title, description, audioUrl? | ttsText?, order
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
Storage paths: `/destinations/{id}/images/{n}.jpg`, `/destinations/{id}/audio/{segmentId}.mp3`,
`/ar/{destId}/markers/{n}.jpg`, `/tiles/{townId}/pack.mbtiles`.

Denormalize for offline read patterns (a bundle carries what a town needs).
