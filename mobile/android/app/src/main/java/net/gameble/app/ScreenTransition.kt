package net.gameble.app

import android.graphics.Bitmap
import android.graphics.Color
import android.graphics.Rect
import android.os.Handler
import android.os.HandlerThread
import android.view.PixelCopy
import android.view.View
import android.view.ViewGroup
import android.view.Window
import android.widget.FrameLayout
import android.widget.ImageView
import androidx.core.content.ContextCompat
import androidx.core.view.isVisible
import androidx.interpolator.view.animation.FastOutSlowInInterpolator
import com.google.android.material.progressindicator.LinearProgressIndicator
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

/**
 * Moves between two screens of a tab along Material's shared horizontal axis: the screen left is held as a
 * picture until the next one's page has drawn, a thin loading bar over it if the page is slow, then the picture
 * slides away as the page slides in.
 */
class ScreenTransition(private val screens: FrameLayout) {
    private var cover: ImageView? = null
    private val loading = LinearProgressIndicator(screens.context).apply {
        isIndeterminate = true
        setIndicatorColor(ContextCompat.getColor(context, R.color.accent))
        trackColor = Color.TRANSPARENT
        trackThickness = resources.getDimensionPixelSize(R.dimen.loading_thickness)
        translationZ = COVER_Z + 1
        visibility = View.GONE
        screens.addView(this, FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT))
    }
    private val showLoading = Runnable { if (cover != null) loading.visibility = View.VISIBLE }
    private var forward = true

    fun leave(window: Window, screen: View, forward: Boolean) {
        drop()
        if (!screen.isVisible || screen.width == 0) return
        val picture = copyOnScreen(window, screen) ?: return
        this.forward = forward
        cover = ImageView(screen.context).apply {
            setImageBitmap(picture)
            translationZ = COVER_Z
            screens.addView(this, FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT))
        }
        screens.postDelayed(showLoading, LOADING_DELAY_MS)
        screens.postDelayed({ arrived(null) }, LONGEST_WAIT_MS)
    }

    fun arrived(page: View?) {
        val picture = cover ?: return
        cover = null
        hideLoading()
        val shift = screens.width * SHIFT * if (forward) 1 else -1
        picture.animate().translationX(-shift).alpha(0f).setDuration(OUT_MS).setInterpolator(FastOutSlowInInterpolator())
            .withEndAction { screens.removeView(picture) }
        page ?: return
        page.translationX = shift
        page.alpha = 0f
        page.animate().translationX(0f).alpha(1f).setStartDelay(OUT_MS / 2).setDuration(IN_MS)
            .setInterpolator(FastOutSlowInInterpolator())
    }

    // Copies the frame already on screen; drawing a WebView again into a bitmap takes most of a second.
    private fun copyOnScreen(window: Window, screen: View): Bitmap? {
        val origin = IntArray(2).also { screen.getLocationInWindow(it) }
        val area = Rect(origin[0], origin[1], origin[0] + screen.width, origin[1] + screen.height)
        val bitmap = Bitmap.createBitmap(screen.width, screen.height, Bitmap.Config.ARGB_8888)
        val copied = CountDownLatch(1)
        var result = PixelCopy.ERROR_UNKNOWN
        PixelCopy.request(window, area, bitmap, { result = it; copied.countDown() }, copyHandler)
        copied.await(COPY_WAIT_MS, TimeUnit.MILLISECONDS)
        return bitmap.takeIf { result == PixelCopy.SUCCESS }
    }

    fun drop() {
        cover?.let { screens.removeView(it) }
        cover = null
        hideLoading()
    }

    private fun hideLoading() {
        screens.removeCallbacks(showLoading)
        loading.visibility = View.GONE
    }

    private companion object {
        val copyHandler = Handler(HandlerThread("screen-copy").apply { start() }.looper)
        const val COPY_WAIT_MS = 100L
        const val SHIFT = 0.08f
        const val OUT_MS = 120L
        const val IN_MS = 260L
        const val COVER_Z = 10f
        const val LOADING_DELAY_MS = 200L
        const val LONGEST_WAIT_MS = 2000L
    }
}
