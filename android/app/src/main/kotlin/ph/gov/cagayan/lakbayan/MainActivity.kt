package ph.gov.cagayan.lakbayan

import android.content.Intent
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

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
class MainActivity : AudioServiceActivity() {
    /** The Dart call waiting on the scan screen. One scan at a time. */
    private var pendingScan: MethodChannel.Result? = null

    /**
     * The AR channel (D-18): `support` asks whether this phone runs ARCore,
     * and `scan` opens [ExhibitScanActivity] and answers when it closes.
     * The Dart half is `ChannelExhibitScanner`.
     */
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, AR_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "support" -> ExhibitScanActivity.support(this, result::success)
                    "scan" -> {
                        if (pendingScan != null) {
                            result.error("busy", "A scan is already open.", null)
                        } else {
                            pendingScan = result
                            @Suppress("DEPRECATION")
                            startActivityForResult(
                                ExhibitScanActivity.intent(this, call.arguments as? Map<*, *> ?: emptyMap<String, Any>()),
                                REQUEST_SCAN,
                            )
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    @Deprecated("The engine's own plugins still arrive this way.")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode != REQUEST_SCAN) {
            @Suppress("DEPRECATION")
            super.onActivityResult(requestCode, resultCode, data)
            return
        }
        val result = pendingScan ?: return
        pendingScan = null
        // Back, or the close button, sets no result: a cancel.
        result.success(
            mapOf(
                "result" to (data?.getStringExtra(ExhibitScanActivity.EXTRA_RESULT) ?: "cancelled"),
                "id" to data?.getStringExtra(ExhibitScanActivity.EXTRA_ID),
            ),
        )
    }

    private companion object {
        const val AR_CHANNEL = "ph.gov.cagayan.lakbayan/ar"
        const val REQUEST_SCAN = 7300
    }
}
