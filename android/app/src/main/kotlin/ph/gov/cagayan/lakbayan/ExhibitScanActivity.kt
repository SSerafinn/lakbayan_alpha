package ph.gov.cagayan.lakbayan

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.opengl.GLES20
import android.opengl.GLSurfaceView
import android.opengl.Matrix
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.util.TypedValue
import android.view.Gravity
import android.view.HapticFeedbackConstants
import android.view.Surface
import android.view.View
import android.view.ViewGroup.LayoutParams.MATCH_PARENT
import android.view.ViewGroup.LayoutParams.WRAP_CONTENT
import android.view.WindowInsets
import android.widget.FrameLayout
import android.widget.ImageButton
import android.widget.LinearLayout
import android.widget.TextView
import com.google.ar.core.ArCoreApk
import com.google.ar.core.AugmentedImage
import com.google.ar.core.AugmentedImageDatabase
import com.google.ar.core.Camera
import com.google.ar.core.Config
import com.google.ar.core.Pose
import com.google.ar.core.Session
import com.google.ar.core.TrackingState
import com.google.ar.core.exceptions.CameraNotAvailableException
import com.google.ar.core.exceptions.UnavailableException
import javax.microedition.khronos.egl.EGLConfig
import javax.microedition.khronos.opengles.GL10
import kotlin.math.max
import kotlin.math.roundToInt

/**
 * The scan screen (D-18): the camera, full screen, looking for a museum's
 * exhibits by their marker images. When it finds one, an outline locks on to
 * it in the camera image ([ExhibitHighlight]) and a card names it; a tap on
 * either ends the screen with that exhibit's id, and the app opens its
 * story. Back ends it with nothing.
 *
 * A separate activity rather than a camera view inside a Flutter screen, so
 * that AR stays isolated: whatever goes wrong here ends this screen, and the
 * app gets the exhibits as a list instead. The result is one of
 * [RESULT_FOUND], [RESULT_CAMERA_DENIED] or [RESULT_UNAVAILABLE] in
 * [EXTRA_RESULT]; a plain cancel is Back. `MainActivity` hands it to Dart
 * over the `ph.gov.cagayan.lakbayan/ar` channel.
 *
 * What it shows comes from the app: the markers as files already on the
 * phone (downloaded with the town, or cached), and the theme's colours, so
 * nothing here is a second copy of the brand.
 */
class ExhibitScanActivity : Activity(), GLSurfaceView.Renderer {
    private class Marker(
        val id: String,
        val path: String,
        val widthM: Float,
        val title: String,
        val description: String,
    )

    private class Colours(colours: IntArray) {
        val primary = colours[0]
        val onPrimary = colours[1]
        val surface = colours[2]
        val onSurface = colours[3]
        val onSurfaceVariant = colours[4]
    }

    private lateinit var markers: List<Marker>
    private lateinit var colours: Colours

    private lateinit var surfaceView: GLSurfaceView
    private lateinit var highlight: ExhibitHighlight
    private lateinit var hint: TextView
    private lateinit var card: LinearLayout
    private lateinit var cardTitle: TextView
    private lateinit var cardDescription: TextView

    private val background = CameraBackground()

    /** Read by the GL thread, written by the main one. */
    @Volatile private var session: Session? = null
    @Volatile private var running = false
    @Volatile private var rotation = Surface.ROTATION_0

    /** The image database is in place: the session can run. */
    private var configured = false
    private var resumed = false
    private var installRequested = false
    private var askedForCamera = false

    // GL thread only.
    private var textureBound = false
    private var geometryChanged = false
    private var viewportWidth = 0
    private var viewportHeight = 0
    private val projection = FloatArray(16)
    private val view = FloatArray(16)
    private val viewProjection = FloatArray(16)
    private val corner = FloatArray(4)
    private val clip = FloatArray(4)
    private var outlined = false

    /**
     * The exhibit on the card, if any. Written on the main thread; the GL
     * thread reads it to keep the outline on the same exhibit while two are
     * in view.
     */
    @Volatile private var shownId: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val ids = intent.getStringArrayExtra(EXTRA_IDS).orEmpty()
        val paths = intent.getStringArrayExtra(EXTRA_PATHS).orEmpty()
        val titles = intent.getStringArrayExtra(EXTRA_TITLES).orEmpty()
        val descriptions = intent.getStringArrayExtra(EXTRA_DESCRIPTIONS).orEmpty()
        val widths = intent.getFloatArrayExtra(EXTRA_WIDTHS) ?: FloatArray(0)
        markers = ids.indices
            .filter { it < paths.size && it < titles.size && it < widths.size }
            .map {
                Marker(ids[it], paths[it], widths[it], titles[it], descriptions.getOrElse(it) { "" })
            }
        colours = Colours(intent.getIntArrayExtra(EXTRA_COLOURS)?.takeIf { it.size == 5 } ?: FALLBACK_COLOURS)

        if (markers.isEmpty()) {
            finishWith(RESULT_UNAVAILABLE)
            return
        }
        setContentView(buildViews(intent.getStringExtra(EXTRA_PLACE).orEmpty()))
    }

    override fun onResume() {
        super.onResume()
        resumed = true
        rotation = displayRotation()
        if (session == null && !startSession()) return
        resumeSession()
    }

    override fun onPause() {
        super.onPause()
        resumed = false
        if (running) {
            running = false
            // GLSurfaceView.onPause waits for the GL thread, so no frame is
            // mid-update when the session pauses under it.
            surfaceView.onPause()
            session?.pause()
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        session?.close()
        session = null
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != REQUEST_CAMERA) return
        // Granted: onResume follows the dialog and carries on from there.
        if (grantResults.firstOrNull() != PackageManager.PERMISSION_GRANTED) {
            finishWith(RESULT_CAMERA_DENIED)
        }
    }

    /**
     * The camera permission, then ARCore itself, then a session. False while
     * waiting on the visitor (a permission dialog, the Play Store) or once
     * the screen is finishing.
     */
    private fun startSession(): Boolean {
        if (checkSelfPermission(Manifest.permission.CAMERA) != PackageManager.PERMISSION_GRANTED) {
            if (!askedForCamera) {
                askedForCamera = true
                requestPermissions(arrayOf(Manifest.permission.CAMERA), REQUEST_CAMERA)
            }
            return false
        }
        return try {
            // Asks the Play Store for ARCore when it is missing or too old,
            // once; back from there, it either is installed now or throws.
            if (ArCoreApk.getInstance().requestInstall(this, !installRequested) ==
                ArCoreApk.InstallStatus.INSTALL_REQUESTED
            ) {
                installRequested = true
                return false
            }
            val created = Session(this)
            session = created
            buildDatabase(created)
            true
        } catch (e: UnavailableException) {
            Log.w(TAG, "ARCore is not available: $e")
            finishWith(RESULT_UNAVAILABLE)
            false
        } catch (e: Exception) {
            Log.w(TAG, "Couldn't start an AR session", e)
            finishWith(RESULT_UNAVAILABLE)
            false
        }
    }

    /**
     * Decodes each marker and adds it to the session's image database, off
     * the main thread: ARCore takes tens of milliseconds an image. A marker it
     * refuses (too few features to track) is skipped; with none left, there
     * is nothing to look for.
     */
    private fun buildDatabase(target: Session) {
        Thread {
            val database = AugmentedImageDatabase(target)
            var added = 0
            for (marker in markers) {
                val bitmap = decode(marker.path)
                if (bitmap == null) {
                    Log.w(TAG, "Couldn't read the marker for '${marker.id}'")
                    continue
                }
                try {
                    database.addImage(marker.id, bitmap, marker.widthM)
                    added++
                } catch (e: Exception) {
                    Log.w(TAG, "ARCore refused the marker for '${marker.id}': $e")
                }
            }
            runOnUiThread {
                if (isFinishing || session !== target) return@runOnUiThread
                if (added == 0) {
                    finishWith(RESULT_UNAVAILABLE)
                    return@runOnUiThread
                }
                try {
                    target.configure(
                        Config(target).apply {
                            augmentedImageDatabase = database
                            // Exhibits are looked at from close up.
                            focusMode = Config.FocusMode.AUTO
                            updateMode = Config.UpdateMode.LATEST_CAMERA_IMAGE
                        },
                    )
                    configured = true
                    resumeSession()
                } catch (e: Exception) {
                    Log.w(TAG, "Couldn't configure the AR session", e)
                    finishWith(RESULT_UNAVAILABLE)
                }
            }
        }.start()
    }

    private fun resumeSession() {
        val current = session ?: return
        if (!configured || !resumed || running) return
        try {
            current.resume()
        } catch (e: CameraNotAvailableException) {
            Log.w(TAG, "The camera is not available", e)
            finishWith(RESULT_UNAVAILABLE)
            return
        }
        running = true
        surfaceView.onResume()
    }

    // ---- GL thread -------------------------------------------------------

    override fun onSurfaceCreated(gl: GL10?, config: EGLConfig?) {
        GLES20.glClearColor(0f, 0f, 0f, 1f)
        background.create()
        textureBound = false
    }

    override fun onSurfaceChanged(gl: GL10?, width: Int, height: Int) {
        GLES20.glViewport(0, 0, width, height)
        viewportWidth = width
        viewportHeight = height
        geometryChanged = true
    }

    override fun onDrawFrame(gl: GL10?) {
        GLES20.glClear(GLES20.GL_COLOR_BUFFER_BIT or GLES20.GL_DEPTH_BUFFER_BIT)
        val current = session ?: return
        if (!running) return
        if (!textureBound) {
            current.setCameraTextureName(background.textureId)
            textureBound = true
        }
        if (geometryChanged) {
            current.setDisplayGeometry(rotation, viewportWidth, viewportHeight)
            geometryChanged = false
        }
        val frame = try {
            current.update()
        } catch (e: Exception) {
            Log.w(TAG, "Dropped a camera frame: $e")
            return
        }
        background.draw(frame)

        // Every exhibit the camera can see right now. FULL_TRACKING only: an
        // image ARCore merely remembers (LAST_KNOWN_POSE) is out of view, and
        // an outline there would point at nothing.
        val seen = current.getAllTrackables(AugmentedImage::class.java).filter {
            it.trackingState == TrackingState.TRACKING &&
                it.trackingMethod == AugmentedImage.TrackingMethod.FULL_TRACKING
        }
        val focus = seen.firstOrNull { it.name == shownId } ?: seen.firstOrNull()
        val points = focus?.let { outlineOf(frame.camera, it) }
        if (focus != null && points != null) {
            outlined = true
            val id = focus.name
            runOnUiThread {
                show(id)
                highlight.track(id, points)
            }
        } else if (outlined) {
            outlined = false
            runOnUiThread { highlight.lose() }
        }
    }

    /**
     * [image]'s four corners on screen, clockwise from its top left, in the
     * surface's pixels — which are the highlight's, both filling the screen.
     * Null when a corner is behind the camera.
     */
    private fun outlineOf(camera: Camera, image: AugmentedImage): FloatArray? {
        camera.getProjectionMatrix(projection, 0, 0.05f, 50f)
        camera.getViewMatrix(view, 0)
        Matrix.multiplyMM(viewProjection, 0, projection, 0, view, 0)
        val pose: Pose = image.centerPose
        val halfX = image.extentX / 2f
        val halfZ = image.extentZ / 2f
        // In the image's own frame X runs to its right and Z down it.
        val local = floatArrayOf(-halfX, -halfZ, halfX, -halfZ, halfX, halfZ, -halfX, halfZ)
        val out = FloatArray(8)
        for (i in 0 until 4) {
            val world = pose.transformPoint(floatArrayOf(local[2 * i], 0f, local[2 * i + 1]))
            corner[0] = world[0]
            corner[1] = world[1]
            corner[2] = world[2]
            corner[3] = 1f
            Matrix.multiplyMV(clip, 0, viewProjection, 0, corner, 0)
            if (clip[3] <= 0f) return null
            out[2 * i] = (clip[0] / clip[3] + 1f) / 2f * viewportWidth
            out[2 * i + 1] = (1f - clip[1] / clip[3]) / 2f * viewportHeight
        }
        return out
    }

    // ---- The screen ------------------------------------------------------

    /** The card names [id]; a tap on it ends the screen with that exhibit. */
    private fun show(id: String) {
        if (id == shownId || isFinishing) return
        val marker = markers.firstOrNull { it.id == id } ?: return
        val first = shownId == null
        shownId = id
        cardTitle.text = marker.title
        cardDescription.text = marker.description
        cardDescription.visibility = if (marker.description.isBlank()) View.GONE else View.VISIBLE
        card.contentDescription = marker.title
        hint.visibility = View.GONE
        if (first) {
            card.alpha = 0f
            card.visibility = View.VISIBLE
            card.animate().alpha(1f).setDuration(180).start()
        }
        card.performHapticFeedback(
            if (Build.VERSION.SDK_INT >= 30) HapticFeedbackConstants.CONFIRM
            else HapticFeedbackConstants.VIRTUAL_KEY,
        )
    }

    private fun buildViews(placeName: String): View {
        surfaceView = GLSurfaceView(this).apply {
            preserveEGLContextOnPause = true
            setEGLContextClientVersion(2)
            setEGLConfigChooser(8, 8, 8, 8, 16, 0)
            setRenderer(this@ExhibitScanActivity)
            renderMode = GLSurfaceView.RENDERMODE_CONTINUOUSLY
        }
        highlight = ExhibitHighlight(this, line = colours.surface, tint = colours.primary).apply {
            onTap = { openShown() }
        }

        val close = ImageButton(this).apply {
            setImageResource(R.drawable.ic_scan_close)
            setColorFilter(colours.onSurface)
            background = pill(colours.surface, alpha = 0.92f)
            contentDescription = getString(R.string.scan_close)
            setOnClickListener { finish() }
        }
        val place = TextView(this).apply {
            text = placeName
            textSize = 15f
            typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
            setTextColor(colours.onSurface)
            maxLines = 1
            ellipsize = android.text.TextUtils.TruncateAt.END
            background = pill(colours.surface, alpha = 0.92f)
            setPadding(16.dp, 0, 16.dp, 0)
            gravity = Gravity.CENTER_VERTICAL
            visibility = if (placeName.isBlank()) View.GONE else View.VISIBLE
        }
        val top = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            addView(close, LinearLayout.LayoutParams(44.dp, 44.dp))
            addView(
                place,
                LinearLayout.LayoutParams(WRAP_CONTENT, 44.dp).apply { marginStart = 8.dp },
            )
        }

        hint = TextView(this).apply {
            text = getString(R.string.scan_hint)
            textSize = 15f
            setTextColor(colours.onSurface)
            gravity = Gravity.CENTER
            background = pill(colours.surface, alpha = 0.92f)
            setPadding(20.dp, 12.dp, 20.dp, 12.dp)
        }

        cardTitle = TextView(this).apply {
            textSize = 20f
            typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
            setTextColor(colours.onSurface)
            accessibilityLiveRegion = View.ACCESSIBILITY_LIVE_REGION_POLITE
        }
        cardDescription = TextView(this).apply {
            textSize = 15f
            setTextColor(colours.onSurfaceVariant)
            setPadding(0, 4.dp, 0, 0)
        }
        val open = TextView(this).apply {
            text = getString(R.string.scan_open)
            textSize = 16f
            typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
            setTextColor(colours.onPrimary)
            gravity = Gravity.CENTER
            background = pill(colours.primary)
            isClickable = true
            isFocusable = true
            setOnClickListener { openShown() }
        }
        card = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            background = GradientDrawable().apply {
                setColor(colours.surface)
                cornerRadius = 16.dp.toFloat()
            }
            setPadding(16.dp, 16.dp, 16.dp, 16.dp)
            visibility = View.GONE
            isClickable = true
            setOnClickListener { openShown() }
            addView(cardTitle)
            addView(cardDescription)
            addView(
                open,
                LinearLayout.LayoutParams(MATCH_PARENT, 50.dp).apply { topMargin = 16.dp },
            )
        }

        val overlay = FrameLayout(this).apply {
            addView(top, FrameLayout.LayoutParams(WRAP_CONTENT, WRAP_CONTENT, Gravity.TOP or Gravity.START))
            addView(hint, FrameLayout.LayoutParams(WRAP_CONTENT, WRAP_CONTENT, Gravity.BOTTOM or Gravity.CENTER_HORIZONTAL))
            addView(card, FrameLayout.LayoutParams(MATCH_PARENT, WRAP_CONTENT, Gravity.BOTTOM))
        }
        val root = FrameLayout(this).apply {
            setBackgroundColor(Color.BLACK)
            addView(surfaceView, FrameLayout.LayoutParams(MATCH_PARENT, MATCH_PARENT))
            addView(highlight, FrameLayout.LayoutParams(MATCH_PARENT, MATCH_PARENT))
            addView(overlay, FrameLayout.LayoutParams(MATCH_PARENT, MATCH_PARENT))
        }
        // Edge to edge (the default from API 35): the camera runs under the
        // system bars, the controls stay clear of them.
        root.setOnApplyWindowInsetsListener { _, insets ->
            val (top, bottom) = if (Build.VERSION.SDK_INT >= 30) {
                insets.getInsets(WindowInsets.Type.systemBars()).let { it.top to it.bottom }
            } else {
                @Suppress("DEPRECATION")
                insets.systemWindowInsetTop to insets.systemWindowInsetBottom
            }
            overlay.setPadding(12.dp, top + 8.dp, 12.dp, bottom + 16.dp)
            insets
        }
        return root
    }

    private fun openShown() {
        val id = shownId ?: return
        finishWith(RESULT_FOUND, id)
    }

    private fun finishWith(result: String, id: String? = null) {
        setResult(
            RESULT_OK,
            Intent().putExtra(EXTRA_RESULT, result).putExtra(EXTRA_ID, id),
        )
        finish()
    }

    private fun pill(colour: Int, alpha: Float = 1f) = GradientDrawable().apply {
        setColor(Color.argb((Color.alpha(colour) * alpha).roundToInt(), Color.red(colour), Color.green(colour), Color.blue(colour)))
        cornerRadius = 999.dp.toFloat()
    }

    private fun displayRotation(): Int =
        if (Build.VERSION.SDK_INT >= 30) {
            display?.rotation ?: Surface.ROTATION_0
        } else {
            @Suppress("DEPRECATION")
            windowManager.defaultDisplay.rotation
        }

    private val Int.dp: Int
        get() = TypedValue.applyDimension(
            TypedValue.COMPLEX_UNIT_DIP,
            toFloat(),
            resources.displayMetrics,
        ).roundToInt()

    companion object {
        private const val TAG = "ExhibitScan"
        private const val REQUEST_CAMERA = 7301

        const val EXTRA_RESULT = "result"
        const val EXTRA_ID = "id"
        const val RESULT_FOUND = "found"
        const val RESULT_CAMERA_DENIED = "cameraDenied"
        const val RESULT_UNAVAILABLE = "unavailable"

        private const val EXTRA_PLACE = "placeName"
        private const val EXTRA_IDS = "ids"
        private const val EXTRA_PATHS = "paths"
        private const val EXTRA_WIDTHS = "widths"
        private const val EXTRA_TITLES = "titles"
        private const val EXTRA_DESCRIPTIONS = "descriptions"
        private const val EXTRA_COLOURS = "colours"

        /** Only for a call that sent none: the app always sends its theme. */
        private val FALLBACK_COLOURS = intArrayOf(
            Color.DKGRAY, Color.WHITE, Color.WHITE, Color.BLACK, Color.DKGRAY,
        )

        /** ARCore wants no more than this; larger only costs memory. */
        private const val MAX_MARKER_EDGE = 1600

        /**
         * The scan screen for the channel's `scan` arguments: `placeName`,
         * `markers` (each `id`, `path`, `widthM`, `title`, `description`) and
         * `colours` as ARGB ints, as `ChannelExhibitScanner` sends them.
         */
        fun intent(context: Context, arguments: Map<*, *>): Intent {
            val markers = (arguments["markers"] as? List<*>).orEmpty().filterIsInstance<Map<*, *>>()
            val colours = arguments["colors"] as? Map<*, *>
            fun colour(name: String, fallback: Int) =
                (colours?.get(name) as? Number)?.toLong()?.toInt() ?: fallback
            return Intent(context, ExhibitScanActivity::class.java)
                .putExtra(EXTRA_PLACE, arguments["placeName"] as? String)
                .putExtra(EXTRA_IDS, markers.map { it["id"] as? String ?: "" }.toTypedArray())
                .putExtra(EXTRA_PATHS, markers.map { it["path"] as? String ?: "" }.toTypedArray())
                .putExtra(EXTRA_TITLES, markers.map { it["title"] as? String ?: "" }.toTypedArray())
                .putExtra(EXTRA_DESCRIPTIONS, markers.map { it["description"] as? String ?: "" }.toTypedArray())
                .putExtra(
                    EXTRA_WIDTHS,
                    markers.map { (it["widthM"] as? Number)?.toFloat() ?: 0f }.toFloatArray(),
                )
                .putExtra(
                    EXTRA_COLOURS,
                    intArrayOf(
                        colour("primary", FALLBACK_COLOURS[0]),
                        colour("onPrimary", FALLBACK_COLOURS[1]),
                        colour("surface", FALLBACK_COLOURS[2]),
                        colour("onSurface", FALLBACK_COLOURS[3]),
                        colour("onSurfaceVariant", FALLBACK_COLOURS[4]),
                    ),
                )
        }

        /**
         * Whether this phone runs ARCore, as the channel's `support` answers:
         * `supported`, `installable` (it can, once the Play Store installs or
         * updates ARCore), `unsupported`, or `unknown`.
         *
         * The first check after a cold start can come back "still checking";
         * it is asked again a few times rather than answered as unknown.
         */
        fun support(context: Context, answer: (String) -> Unit, attempts: Int = 10) {
            val availability = ArCoreApk.getInstance().checkAvailability(context)
            if (availability.isTransient && attempts > 0) {
                Handler(Looper.getMainLooper()).postDelayed(
                    { support(context, answer, attempts - 1) },
                    200,
                )
                return
            }
            answer(
                when (availability) {
                    ArCoreApk.Availability.SUPPORTED_INSTALLED -> "supported"
                    ArCoreApk.Availability.SUPPORTED_APK_TOO_OLD,
                    ArCoreApk.Availability.SUPPORTED_NOT_INSTALLED,
                    -> "installable"
                    ArCoreApk.Availability.UNSUPPORTED_DEVICE_NOT_CAPABLE -> "unsupported"
                    else -> "unknown"
                },
            )
        }

        /** A marker as a bitmap no larger than ARCore can use. */
        private fun decode(path: String): Bitmap? {
            val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
            BitmapFactory.decodeFile(path, bounds)
            if (bounds.outWidth <= 0 || bounds.outHeight <= 0) return null
            var sample = 1
            while (max(bounds.outWidth, bounds.outHeight) / sample > MAX_MARKER_EDGE) sample *= 2
            return BitmapFactory.decodeFile(path, BitmapFactory.Options().apply { inSampleSize = sample })
        }
    }
}
