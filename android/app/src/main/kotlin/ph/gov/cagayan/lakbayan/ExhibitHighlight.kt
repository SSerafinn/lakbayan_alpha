package ph.gov.cagayan.lakbayan

import android.animation.ValueAnimator
import android.annotation.SuppressLint
import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.LinearGradient
import android.graphics.Paint
import android.graphics.Path
import android.graphics.Rect
import android.graphics.RectF
import android.graphics.Region
import android.graphics.Shader
import android.util.TypedValue
import android.view.MotionEvent
import android.view.View
import android.view.animation.DecelerateInterpolator
import android.view.animation.PathInterpolator
import kotlin.math.PI
import kotlin.math.hypot
import kotlin.math.min
import kotlin.math.sin

/**
 * The outline that holds on to a recognised exhibit in the camera image
 * (D-18): white corner brackets on the exhibit's four corners, over a faint
 * wash of the theme's primary.
 *
 * It says "this one" where the visitor is already looking, rather than only
 * in the card at the foot of the screen. On lock-on the brackets close in
 * from a little wide, the wash flashes once and settles, and a shine crosses
 * the exhibit; looking away fades it, and finding the exhibit again plays it
 * once more. All three ride ValueAnimator, which honours the system's
 * animation scale, so with animations off it simply appears in place.
 *
 * A tap inside the outline does what the card's button does.
 *
 * [track] takes the corners in this view's pixels, clockwise from the
 * exhibit's top left. Main thread only.
 */
@SuppressLint("ViewConstructor")
class ExhibitHighlight(
    context: Context,
    line: Int,
    private val tint: Int,
) : View(context) {
    var onTap: (() -> Unit)? = null

    private val corners = FloatArray(8)
    private val drawn = FloatArray(8)
    private var hasCorners = false
    private var target: String? = null
    private var present = false

    private val outline = Path()
    private val brackets = Path()
    private val bounds = RectF()
    private val hitRegion = Region()
    private var pressed = false

    private val wash = Paint(Paint.ANTI_ALIAS_FLAG).apply { style = Paint.Style.FILL }
    private val shine = Paint(Paint.ANTI_ALIAS_FLAG).apply { style = Paint.Style.FILL }
    private val bracket = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        strokeWidth = dp(4f)
        strokeCap = Paint.Cap.ROUND
        strokeJoin = Paint.Join.ROUND
        color = line
    }

    /** A darker line under the white one, so it reads on a pale exhibit too. */
    private val bracketShade = Paint(bracket).apply {
        strokeWidth = dp(7f)
        color = Color.argb(70, 0, 0, 0)
    }

    /** 0 to 1 over the lock-on: the brackets settle, the wash flashes. */
    private val lockOn = ValueAnimator.ofFloat(0f, 1f).apply {
        duration = 520
        interpolator = PathInterpolator(0.2f, 0f, 0f, 1f)
        addUpdateListener { invalidate() }
    }

    /** The shine's way across the exhibit, once, just after lock-on. */
    private val sweep = ValueAnimator.ofFloat(0f, 1f).apply {
        duration = 750
        startDelay = 160
        interpolator = DecelerateInterpolator()
        addUpdateListener { invalidate() }
    }

    init {
        alpha = 0f
        // The card is the accessible control; this is what the eye follows.
        importantForAccessibility = IMPORTANT_FOR_ACCESSIBILITY_NO
    }

    /** The camera sees exhibit [id] at [points]. */
    fun track(id: String, points: FloatArray) {
        System.arraycopy(points, 0, corners, 0, 8)
        hasCorners = true
        if (id != target || !present) {
            target = id
            lockOn.start()
            sweep.start()
        }
        if (!present) {
            present = true
            animate().cancel()
            animate().alpha(1f).setDuration(140).start()
        }
        invalidate()
    }

    /** The camera has looked away. The outline fades where it last was. */
    fun lose() {
        if (!present) return
        present = false
        pressed = false
        animate().cancel()
        animate().alpha(0f).setDuration(240).start()
    }

    override fun onDraw(canvas: Canvas) {
        if (!hasCorners) return
        val t = lockOn.animatedValue as Float

        // Spread about the centre: 12% wide at the start, settled at the end.
        val cx = (corners[0] + corners[2] + corners[4] + corners[6]) / 4f
        val cy = (corners[1] + corners[3] + corners[5] + corners[7]) / 4f
        val spread = 1f + 0.12f * (1f - t)
        for (i in 0 until 4) {
            drawn[2 * i] = cx + (corners[2 * i] - cx) * spread
            drawn[2 * i + 1] = cy + (corners[2 * i + 1] - cy) * spread
        }
        outline.rewind()
        outline.moveTo(drawn[0], drawn[1])
        for (i in 1 until 4) outline.lineTo(drawn[2 * i], drawn[2 * i + 1])
        outline.close()

        // The wash: a flash at the middle of the lock-on, then a faint tint.
        val flash = if (t < 1f) sin(PI * t).toFloat() else 0f
        wash.color = withAlpha(tint, 0.10f + 0.24f * flash)
        canvas.drawPath(outline, wash)

        if (sweep.isRunning) drawShine(canvas, sweep.animatedValue as Float)

        brackets.rewind()
        for (i in 0 until 4) {
            val x = drawn[2 * i]
            val y = drawn[2 * i + 1]
            val prev = (i + 3) % 4
            val next = (i + 1) % 4
            arm(x, y, drawn[2 * prev], drawn[2 * prev + 1], moveTo = true)
            brackets.lineTo(x, y)
            arm(x, y, drawn[2 * next], drawn[2 * next + 1], moveTo = false)
        }
        val ink = min(1f, t * 2.5f)
        bracketShade.alpha = (70 * ink).toInt()
        bracket.alpha = (255 * ink).toInt()
        canvas.drawPath(brackets, bracketShade)
        canvas.drawPath(brackets, bracket)
    }

    /**
     * One end of a corner's bracket: from the corner toward a neighbour, a
     * fifth of that edge, kept between 16 and 44 dp so a far exhibit still
     * has corners and a near one is not boxed in.
     */
    private fun arm(x: Float, y: Float, toX: Float, toY: Float, moveTo: Boolean) {
        val length = hypot(toX - x, toY - y)
        if (length <= 0f) return
        val reach = (length * 0.2f).coerceIn(dp(16f), dp(44f)).coerceAtMost(length / 2f)
        val endX = x + (toX - x) / length * reach
        val endY = y + (toY - y) / length * reach
        if (moveTo) brackets.moveTo(endX, endY) else brackets.lineTo(endX, endY)
    }

    /** A soft white band across the exhibit, top left to bottom right. */
    private fun drawShine(canvas: Canvas, progress: Float) {
        outline.computeBounds(bounds, true)
        val diagonal = bounds.width() + bounds.height()
        val band = diagonal * 0.18f
        // Along the line x = y from the top left: enter fully off, leave fully off.
        val at = -band + (diagonal + 2 * band) * progress
        val half = at / 2f
        val startX = bounds.left + half - band / 4f
        val startY = bounds.top + half - band / 4f
        shine.shader = LinearGradient(
            startX,
            startY,
            startX + band / 2f,
            startY + band / 2f,
            intArrayOf(Color.TRANSPARENT, Color.argb(110, 255, 255, 255), Color.TRANSPARENT),
            null,
            Shader.TileMode.CLAMP,
        )
        canvas.save()
        canvas.clipPath(outline)
        canvas.drawRect(bounds, shine)
        canvas.restore()
    }

    @SuppressLint("ClickableViewAccessibility")
    override fun onTouchEvent(event: MotionEvent): Boolean {
        if (!present || !hasCorners || onTap == null) return false
        when (event.actionMasked) {
            MotionEvent.ACTION_DOWN -> {
                pressed = inside(event.x, event.y)
                return pressed
            }
            MotionEvent.ACTION_UP -> {
                if (pressed && inside(event.x, event.y)) {
                    performClick()
                    onTap?.invoke()
                }
                pressed = false
            }
            MotionEvent.ACTION_CANCEL -> pressed = false
        }
        return pressed
    }

    override fun performClick(): Boolean = super.performClick()

    private fun inside(x: Float, y: Float): Boolean {
        outline.computeBounds(bounds, true)
        val clip = Rect()
        bounds.roundOut(clip)
        hitRegion.setPath(outline, Region(clip))
        return hitRegion.contains(x.toInt(), y.toInt())
    }

    private fun withAlpha(colour: Int, fraction: Float) =
        Color.argb((255 * fraction).toInt(), Color.red(colour), Color.green(colour), Color.blue(colour))

    private fun dp(value: Float) =
        TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, value, resources.displayMetrics)
}
