# Architecture

Flutter client (Android-first, **offline-first**) ↔ Firebase backend; device SDKs
for maps, AR, and TTS; a separate Admin CMS web app on the same Firebase project.

```
Client (Flutter)            Firebase                 Device / External
  UI / Screens              Auth                       flutter_map + MapLibre/OSM
  State (Riverpod)   <-->   Firestore (data)           ARCore (museum AR)
  Local cache (Hive)        Storage (images/audio)     flutter_tts
  Map / Audio / AR          Cloud Functions
        ^
        |
  Admin Web App (CMS) -----> Firebase
```

- **Read path:** local-first (Hive / Firestore offline persistence) → network fallback.
- **Write path:** minimal — user profile, saved tours, downloads. Content writes are admin-only.
- **Offline bundles:** `generateOfflineBundle(townId)` (Cloud Function) returns a manifest of
  destinations + asset URLs; the client downloads assets + a map tile pack per town, tracks
  them in Hive, and marks the bundle `version`. Re-download when the version bumps.
- **AR module:** isolated `features/ar`; native ARCore Augmented Images behind a Dart interface;
  app runs fully without it; unsupported devices fall back to Destination Detail.
- **Cloud Functions (`functions/`):** callables for what a client must never do itself.
  Today that is admin promotion (`setAdminRole`, `listAdmins` — the CMS Users screen);
  `generateOfflineBundle` joins them in Phase 3. Region and conventions: D-12.
