# Tech stack

| Layer | Choice | Notes |
|---|---|---|
| Client | Flutter · Dart | go_router · flutter_riverpod · freezed |
| Local | Hive (+ Firestore offline persistence) | simple, stable; Isar if complex queries appear |
| Maps | flutter_map + MapLibre/OSM | offline tiles; Mapbox is the paid alternative |
| Audio | just_audio + audio_service | flutter_tts for narration |
| AR | ARCore Augmented Images (native channel) | Android-only, stretch, isolated |
| Backend | Firebase | auth · firestore · storage · functions |
| Ops | Analytics · Crashlytics | GitHub Actions CI |

Versions in `pubspec.yaml` are starting constraints — run `flutter pub get` and adjust.
