package net.gameble.app

import android.content.Context
import android.graphics.Canvas
import android.graphics.Paint
import android.provider.Settings
import android.util.AttributeSet
import android.util.TypedValue
import android.view.View
import androidx.core.content.ContextCompat
import androidx.core.content.res.ResourcesCompat

class PullConsoleView @JvmOverloads constructor(context: Context, attrs: AttributeSet? = null) : View(context, attrs) {
    private val density = resources.displayMetrics.density
    private val lime = ContextCompat.getColor(context, R.color.lime)
    private val gold = ContextCompat.getColor(context, R.color.gold)

    private val ground = Paint().apply { color = ContextCompat.getColor(context, R.color.outline) }
    private val frame = Paint().apply {
        color = ContextCompat.getColor(context, R.color.line)
        style = Paint.Style.STROKE
        strokeWidth = 2 * density
    }
    private val cellOutline = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        strokeWidth = 1.5f * density
    }
    private val cellFill = Paint()
    private val text = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        typeface = ResourcesCompat.getFont(context, R.font.jetbrains_mono_bold)
        textSize = TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_SP, 13f, resources.displayMetrics)
        textAlign = Paint.Align.CENTER
    }

    private var lit: Set<Int> = emptySet()
    private var color = lime
    private var word = ".."
    private var sweepStep = 0

    private val sweep = object : Runnable {
        override fun run() {
            lit = setOf(sweepStep % CELLS)
            sweepStep++
            invalidate()
            postDelayed(this, if (animationsOff()) 400L else SWEEP_MS)
        }
    }

    init {
        alpha = 0f
    }

    override fun onMeasure(widthMeasureSpec: Int, heightMeasureSpec: Int) {
        val width = PAD * 2 + CELLS * CELL_W + (CELLS - 1) * CELL_GAP + WORD_GAP + WORD_W
        setMeasuredDimension((width * density).toInt(), (HEIGHT * density).toInt())
    }

    override fun onDraw(canvas: Canvas) {
        canvas.drawRect(0f, 0f, width.toFloat(), height.toFloat(), ground)
        val inset = frame.strokeWidth / 2
        canvas.drawRect(inset, inset, width - inset, height - inset, frame)
        cellOutline.color = color
        cellFill.color = color
        val top = (HEIGHT - CELL_H) / 2 * density
        repeat(CELLS) { index ->
            val left = (PAD + index * (CELL_W + CELL_GAP)) * density
            val right = left + CELL_W * density
            val bottom = top + CELL_H * density
            if (index in lit) canvas.drawRect(left, top, right, bottom, cellFill)
            canvas.drawRect(left, top, right, bottom, cellOutline)
        }
        text.color = color
        val wordCentre = (width / density - PAD - WORD_W / 2) * density
        val baseline = height / 2f - (text.descent() + text.ascent()) / 2
        canvas.drawText(word, wordCentre, baseline, text)
    }

    fun showProgress(progress: Float) {
        removeCallbacks(sweep)
        animate().cancel()
        val full = progress >= 1f
        lit = (0 until if (full) CELLS else (progress * CELLS).toInt()).toSet()
        color = if (full) gold else lime
        word = if (full) "OK" else ".."
        alpha = (progress * 1.4f).coerceAtMost(1f)
        val scale = 0.6f + 0.4f * progress.coerceAtMost(1f)
        scaleX = scale
        scaleY = scale
        invalidate()
    }

    fun startSweep() {
        animate().cancel()
        alpha = 1f
        scaleX = 1f
        scaleY = 1f
        color = lime
        word = "SYNC"
        sweepStep = 0
        removeCallbacks(sweep)
        sweep.run()
    }

    fun hide() {
        removeCallbacks(sweep)
        animate().alpha(0f).setDuration(200).start()
    }

    override fun onDetachedFromWindow() {
        removeCallbacks(sweep)
        super.onDetachedFromWindow()
    }

    private fun animationsOff(): Boolean =
        Settings.Global.getFloat(context.contentResolver, Settings.Global.ANIMATOR_DURATION_SCALE, 1f) == 0f

    private companion object {
        const val CELLS = 5
        const val SWEEP_MS = 110L
        const val PAD = 10f
        const val CELL_W = 8f
        const val CELL_H = 13f
        const val CELL_GAP = 3f
        const val WORD_GAP = 8f
        const val WORD_W = 38f
        const val HEIGHT = 28f
    }
}
