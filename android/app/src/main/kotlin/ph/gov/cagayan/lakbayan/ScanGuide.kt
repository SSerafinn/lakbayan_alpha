package ph.gov.cagayan.lakbayan

import android.annotation.SuppressLint
import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.RectF
import android.util.TypedValue
import android.view.View
import kotlin.math.min

/**
 * The box on the scan screen that says how close to come (D-18): a thin,
 * faint outline the exhibit's picture should fill.
 *
 * ARCore finds a picture only once it takes up a good share of the camera
 * image, and a visitor standing back would otherwise think the scanner is
 * broken. So the box is sized for that minimum — about 70% of the screen's
 * width, square, as label pictures nearly are — and sits a little above the
 * middle, clear of the hint and the card at the foot.
 *
 * It is a guide, not a frame: thinner and fainter than the lock-on
 * brackets, it fades away while an exhibit is locked on and comes back when
 * it is lost. It takes no touches.
 */
@SuppressLint("ViewConstructor")
class ScanGuide(context: Context) : View(context) {
    private val box = RectF()

    private val line = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        strokeWidth = dp(1.5f)
        color = Color.argb(150, 255, 255, 255)
    }

    /** A darker line under the white one, so it shows on a pale wall too. */
    private val shade = Paint(line).apply {
        strokeWidth = dp(3.5f)
        color = Color.argb(40, 0, 0, 0)
    }

    private var hidden = false

    init {
        importantForAccessibility = IMPORTANT_FOR_ACCESSIBILITY_NO
    }

    /** Out of the way while an exhibit is locked on; back once it is lost. */
    fun setLocked(locked: Boolean) {
        if (locked == hidden) return
        hidden = locked
        animate().cancel()
        animate().alpha(if (locked) 0f else 1f).setDuration(if (locked) 160 else 280).start()
    }

    override fun onDraw(canvas: Canvas) {
        val side = min(width * 0.7f, height * 0.45f)
        val cx = width / 2f
        val cy = height * 0.44f
        box.set(cx - side / 2f, cy - side / 2f, cx + side / 2f, cy + side / 2f)
        val radius = dp(16f)
        canvas.drawRoundRect(box, radius, radius, shade)
        canvas.drawRoundRect(box, radius, radius, line)
    }

    private fun dp(value: Float) =
        TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, value, resources.displayMetrics)
}
