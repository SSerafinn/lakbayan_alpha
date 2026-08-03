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
users/{uid}
  profile, savedTourIds[], downloadedTownIds[], role           // role: admin only, never client-writable
```

Enums: `category` = church | nature | heritage | museum | food.
Storage paths: `/destinations/{id}/images/{n}.jpg`, `/destinations/{id}/audio/{segmentId}.mp3`,
`/ar/{destId}/markers/{n}.jpg`, `/tiles/{townId}/pack.mbtiles`.

Denormalize for offline read patterns (a bundle carries what a town needs).
