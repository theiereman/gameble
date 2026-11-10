package net.gameble.app

import android.content.Context
import android.graphics.Canvas
import android.graphics.LinearGradient
import android.graphics.Paint
import android.graphics.Shader
import android.os.SystemClock
import android.provider.Settings
import android.util.AttributeSet
import android.view.View
import androidx.core.content.ContextCompat
import androidx.core.graphics.ColorUtils

class PullBeamView @JvmOverloads constructor(context: Context, attrs: AttributeSet? = null) : View(context, attrs) {
    private val density = resources.displayMetrics.density
    private val lime = colorOf(R.color.lime)
    private val limeGlow = colorOf(R.color.lime_glow)
    private val gold = colorOf(R.color.gold)
    private val sunken = colorOf(R.color.panel_sunken)
    private val track = colorOf(R.color.lime_track)
    private val paint = Paint()
    private val comet = Paint()

    private var progress = 0f
    private var refreshing = false

    init {
        alpha = 0f
    }

    fun showPull(newProgress: Float) {
        animate().cancel()
        refreshing = false
        progress = newProgress
        alpha = if (newProgress > 0f) 1f else 0f
        invalidate()
    }

    fun showRefreshing(nowRefreshing: Boolean) {
        if (nowRefreshing) {
            animate().cancel()
            refreshing = true
            alpha = 1f
            invalidate()
        } else if (refreshing) {
            animate().alpha(0f).setDuration(if (animationsOff()) 0L else FADE_MS).withEndAction { showPull(0f) }.start()
        }
    }

    override fun onDraw(canvas: Canvas) {
        val w = width.toFloat()
        val h = height.toFloat()
        when {
            refreshing -> {
                paint.color = track
                canvas.drawRect(0f, 0f, w, h, paint)
                drawComet(canvas, w, h)
                if (!animationsOff()) postInvalidateOnAnimation()
            }
            progress >= 1f -> {
                paint.color = gold
                canvas.drawRect(0f, 0f, w, h, paint)
            }
            else -> {
                paint.color = sunken
                canvas.drawRect(0f, 0f, w, h, paint)
                val reach = w / 2 * progress
                paint.color = lime
                canvas.drawRect(0f, 0f, reach, h, paint)
                canvas.drawRect(w - reach, 0f, w, h, paint)
            }
        }
    }

    private fun drawComet(canvas: Canvas, w: Float, h: Float) {
        val length = COMET_DP * density
        val elapsed = if (animationsOff()) 0.5f else (SystemClock.uptimeMillis() % SWEEP_MS) / SWEEP_MS.toFloat()
        val head = elapsed * (w + length * 2) - length
        comet.shader = LinearGradient(
            head - length, 0f, head, 0f,
            intArrayOf(ColorUtils.setAlphaComponent(lime, 0), lime, limeGlow),
            floatArrayOf(0f, 0.7f, 1f),
            Shader.TileMode.CLAMP
        )
        canvas.drawRect(head - length, 0f, head, h, comet)
    }

    private fun animationsOff(): Boolean =
        Settings.Global.getFloat(context.contentResolver, Settings.Global.ANIMATOR_DURATION_SCALE, 1f) == 0f

    private fun colorOf(id: Int) = ContextCompat.getColor(context, id)

    private companion object {
        const val COMET_DP = 90f
        const val SWEEP_MS = 900L
        const val FADE_MS = 250L
    }
}
