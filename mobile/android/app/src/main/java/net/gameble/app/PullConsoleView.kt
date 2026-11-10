package net.gameble.app

import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.RectF
import android.os.SystemClock
import android.provider.Settings
import android.util.AttributeSet
import android.util.TypedValue
import android.view.View
import android.view.animation.AccelerateInterpolator
import androidx.core.content.ContextCompat
import androidx.core.content.res.ResourcesCompat
import androidx.core.graphics.ColorUtils
import java.util.Locale

class PullConsoleView @JvmOverloads constructor(context: Context, attrs: AttributeSet? = null) : View(context, attrs) {
    sealed interface Phase {
        data class Pulling(val progress: Float) : Phase
        data class Refreshing(val since: Long) : Phase
        data class Done(val tookMs: Long) : Phase
    }

    private val density = resources.displayMetrics.density
    private val lime = colorOf(R.color.lime)
    private val limeGlow = colorOf(R.color.lime_glow)
    private val gold = colorOf(R.color.gold)
    private val accent = colorOf(R.color.accent)
    private val dim = colorOf(R.color.dim)
    private val raised = colorOf(R.color.panel_raised)
    private val line = colorOf(R.color.line)

    private val fill = Paint()
    private val outline = Paint().apply { color = colorOf(R.color.outline) }
    private val sunken = Paint().apply { color = colorOf(R.color.panel_sunken) }
    private val scanline = Paint().apply { color = Color.argb(6, 255, 255, 255) }
    private val border = Paint().apply {
        style = Paint.Style.STROKE
        strokeWidth = density
    }
    private val bold = textPaint(R.font.jetbrains_mono_bold, 9.5f)
    private val regular = textPaint(R.font.jetbrains_mono, 8.5f)

    private var phase: Phase = Phase.Pulling(0f)
    private var pulseStart: Long? = null
    private var hideToken = 0

    init {
        alpha = 0f
    }

    override fun onMeasure(widthMeasureSpec: Int, heightMeasureSpec: Int) {
        setMeasuredDimension(dp(WIDTH), dp(HEIGHT))
    }

    fun showPull(progress: Float) {
        hideToken++
        if (progress >= 1f && !isFull()) pulseStart = SystemClock.uptimeMillis()
        phase = Phase.Pulling(progress)
        if (progress > 0f) reveal(progress) else tuck()
        invalidate()
    }

    fun showRefreshing(refreshing: Boolean) {
        hideToken++
        val current = phase
        if (refreshing) {
            phase = Phase.Refreshing(SystemClock.uptimeMillis())
            reveal(1f)
        } else if (current is Phase.Refreshing) {
            phase = Phase.Done(SystemClock.uptimeMillis() - current.since)
            val token = hideToken
            postDelayed({ if (hideToken == token) tuck() }, DONE_HOLD_MS)
        }
        invalidate()
    }

    private fun reveal(progress: Float) {
        animate().cancel()
        val reach = progress.coerceAtMost(1f)
        translationY = -(1f - reach) * tuckedDistance()
        alpha = (reach * 1.6f).coerceAtMost(1f)
    }

    private fun tuck() {
        animate().translationY(-tuckedDistance()).alpha(0f)
            .setDuration(if (animationsOff()) 0L else TUCK_MS)
            .setInterpolator(AccelerateInterpolator())
            .start()
    }

    private fun tuckedDistance() = (HEIGHT + REVEALED_GAP) * density

    override fun onDraw(canvas: Canvas) {
        val now = SystemClock.uptimeMillis()
        val pulsing = pulseStart?.let { now - it < PULSE_MS } == true
        if (!pulsing) pulseStart = null
        val panel = RectF(dp(BRACKET).toFloat(), dp(BRACKET).toFloat(), width - dp(BRACKET).toFloat(), height - dp(BRACKET).toFloat())
        drawFrame(canvas, panel, pulsing)
        val left = panel.left + dp(10)
        val right = panel.right - dp(10)
        drawRow(canvas, bold, context.getString(R.string.pull_console_title), accent, value(now), valueColor(), panel.top + dp(7), left, right, cursor = false)
        drawSegments(canvas, segmentColors(now), left, right, panel.top + dp(24))
        val cursor = blinks() && (now / BLINK_MS) % 2 == 0L
        drawRow(canvas, regular, message(now), messageColor(), aux(), dim, panel.top + dp(39), left, right, cursor)
        if (pulsing || phase is Phase.Refreshing) postInvalidateOnAnimation()
    }

    private fun drawFrame(canvas: Canvas, panel: RectF, pulsing: Boolean) {
        val golden = pulsing || isFull() || phase is Phase.Done
        val ring = 2 * density
        canvas.drawRect(panel.left - ring, panel.top - ring, panel.right + ring, panel.bottom + ring, outline)
        canvas.drawRect(panel, sunken)
        var y = panel.top + 2 * density
        while (y < panel.bottom) {
            canvas.drawRect(panel.left, y, panel.right, y + density, scanline)
            y += 3 * density
        }
        border.color = if (pulsing) gold else line
        canvas.drawRect(panel.left + density / 2, panel.top + density / 2, panel.right - density / 2, panel.bottom - density / 2, border)
        fill.color = if (golden) gold else accent
        val arm = 5 * density
        val thick = 2 * density
        val w = width.toFloat()
        val h = height.toFloat()
        canvas.drawRect(0f, 0f, arm, thick, fill)
        canvas.drawRect(0f, 0f, thick, arm, fill)
        canvas.drawRect(w - arm, 0f, w, thick, fill)
        canvas.drawRect(w - thick, 0f, w, arm, fill)
        canvas.drawRect(0f, h - thick, arm, h, fill)
        canvas.drawRect(0f, h - arm, thick, h, fill)
        canvas.drawRect(w - arm, h - thick, w, h, fill)
        canvas.drawRect(w - thick, h - arm, w, h, fill)
    }

    private fun drawSegments(canvas: Canvas, colors: List<Int>, left: Float, right: Float, top: Float) {
        val gap = 2 * density
        val segment = (right - left - gap * (colors.size - 1)) / colors.size
        colors.forEachIndexed { index, color ->
            fill.color = color
            val x = left + index * (segment + gap)
            canvas.drawRect(x, top, x + segment, top + 8 * density, fill)
        }
    }

    private fun drawRow(canvas: Canvas, paint: Paint, start: String, startColor: Int, end: String, endColor: Int,
                        top: Float, left: Float, right: Float, cursor: Boolean) {
        val baseline = top - paint.ascent()
        paint.color = startColor
        canvas.drawText(start, left, baseline, paint)
        if (cursor) {
            fill.color = startColor
            val x = left + paint.measureText(start) + 3 * density
            canvas.drawRect(x, top + density, x + 6 * density, top + paint.textSize + density, fill)
        }
        paint.color = endColor
        canvas.drawText(end, right - paint.measureText(end), baseline, paint)
    }

    private fun value(now: Long): String = when (val current = phase) {
        is Phase.Pulling -> (current.progress * 100).toInt().toString().padStart(3, '0') + "%"
        is Phase.Refreshing -> seconds(now - current.since)
        is Phase.Done -> "100%"
    }

    private fun valueColor(): Int = when (phase) {
        is Phase.Pulling -> if (isFull()) gold else accent
        is Phase.Refreshing -> lime
        is Phase.Done -> gold
    }

    private fun message(now: Long): String = when (val current = phase) {
        is Phase.Pulling -> context.getString(if (isFull()) R.string.pull_console_release else R.string.pull_console_pull)
        is Phase.Refreshing -> context.getString(R.string.pull_console_packet, packet(now - current.since), PACKETS)
        is Phase.Done -> context.getString(R.string.pull_console_done)
    }

    private fun messageColor(): Int = when (phase) {
        is Phase.Pulling -> if (isFull()) gold else dim
        is Phase.Refreshing -> lime
        is Phase.Done -> gold
    }

    private fun aux(): String = when (val current = phase) {
        is Phase.Pulling -> if (isFull()) {
            context.getString(R.string.pull_console_threshold, PULL_DISTANCE_DP)
        } else {
            "${(current.progress * PULL_DISTANCE_DP).toInt()}/${PULL_DISTANCE_DP}dp"
        }
        is Phase.Refreshing -> context.getString(R.string.pull_console_network)
        is Phase.Done -> seconds(current.tookMs)
    }

    private fun blinks() = isFull() || phase is Phase.Refreshing

    private fun segmentColors(now: Long): List<Int> = when (val current = phase) {
        is Phase.Pulling -> {
            val lit = (current.progress * SEGMENTS + 0.5f).toInt()
            val color = if (isFull()) gold else lime
            List(SEGMENTS) { if (it < lit) color else raised }
        }
        is Phase.Refreshing -> if (animationsOff()) {
            List(SEGMENTS) { lime }
        } else {
            val head = ((now / COMET_STEP_MS) % (SEGMENTS + COMET)).toInt()
            List(SEGMENTS) { index ->
                val behind = head - index
                when {
                    behind == 0 -> limeGlow
                    behind in 1 until COMET -> ColorUtils.blendARGB(raised, lime, 1f - behind.toFloat() / COMET)
                    else -> raised
                }
            }
        }
        is Phase.Done -> List(SEGMENTS) { gold }
    }

    private fun packet(elapsedMs: Long) = (1 + (elapsedMs / PACKET_MS).toInt()).coerceAtMost(PACKETS)

    private fun seconds(ms: Long) = String.format(Locale.US, "%.2fs", ms / 1000f)

    private fun isFull() = (phase as? Phase.Pulling)?.let { it.progress >= 1f } == true

    private fun animationsOff(): Boolean =
        Settings.Global.getFloat(context.contentResolver, Settings.Global.ANIMATOR_DURATION_SCALE, 1f) == 0f

    private fun colorOf(id: Int) = ContextCompat.getColor(context, id)

    private fun dp(value: Float) = (value * density).toInt()

    private fun dp(value: Int) = (value * density).toInt()

    private fun textPaint(font: Int, sizeSp: Float) = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        typeface = ResourcesCompat.getFont(context, font)
        textSize = TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_SP, sizeSp, resources.displayMetrics)
        letterSpacing = 0.14f
    }

    private companion object {
        const val WIDTH = 306f
        const val HEIGHT = 64f
        const val BRACKET = 3f
        const val REVEALED_GAP = 6f
        const val SEGMENTS = 24
        const val COMET = 6
        const val PACKETS = 5
        const val PACKET_MS = 320L
        const val COMET_STEP_MS = 45L
        const val BLINK_MS = 420L
        const val PULSE_MS = 350L
        const val DONE_HOLD_MS = 450L
        const val TUCK_MS = 220L
    }
}
