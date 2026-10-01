package ph.gov.cagayan.lakbayan

import com.ryanheise.audioservice.AudioServiceActivity

/**
 * `AudioServiceActivity`, not a bare `FlutterActivity`, and the difference is
 * whether the app starts once or twice.
 *
 * The `audio_service` plugin keeps one cached Flutter engine so that playback
 * can outlive the screen. When it attaches to an activity that is running some
 * *other* engine, it builds that cached engine itself and runs the Dart
 * entrypoint in it — a second, headless copy of the whole app in the same
 * process: `main()` twice, two provider containers, two sets of Firestore
 * listeners. Nothing fails, so nothing says so; the only sign was every
 * startup log line appearing twice, a fraction of a second apart.
 *
 * `AudioServiceActivity` hands this activity that same cached engine, so there
 * is one. The plugin's own documentation asks for it; the dependency arrived
 * before the setup did.
 *
 * One consequence worth knowing: the engine is not destroyed with the
 * activity. Leaving with Back keeps the Dart side alive until the process
 * goes, which is what background audio needs and means the app comes back
 * where it was.
 */
class MainActivity : AudioServiceActivity()
