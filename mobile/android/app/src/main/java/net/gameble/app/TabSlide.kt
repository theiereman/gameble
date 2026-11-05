package net.gameble.app

import android.view.View
import android.view.ViewGroup
import android.webkit.WebView
import androidx.core.view.children
import androidx.interpolator.view.animation.FastOutSlowInInterpolator

/** Slides from one tab to the next in the tab bar's order, once the chosen tab's page has drawn. */
class TabSlide {
    private var shown: View? = null
    private var shownIndex = 0

    fun switched(screen: View, index: Int) {
        val left = shown?.takeIf { it !== screen }
        val towardsRight = index > shownIndex
        shown = screen
        shownIndex = index
        screen.animate().cancel()
        screen.translationZ = 0f
        if (left == null) {
            screen.translationX = 0f
            return
        }
        left.animate().cancel()
        left.visibility = View.VISIBLE
        left.translationX = 0f
        left.translationZ = 1f
        screen.translationX = 0f
        // The chosen tab draws in place under the one being left, since a WebView off screen draws nothing.
        whenDrawn(screen) { slide(screen, left, towardsRight) }
    }

    private fun slide(screen: View, left: View, towardsRight: Boolean) {
        if (shown !== screen) return
        val width = (screen.parent as View).width.toFloat()
        screen.translationX = if (towardsRight) width else -width
        left.translationZ = 0f
        screen.animate().translationX(0f).setDuration(SLIDE_MS).setInterpolator(FastOutSlowInInterpolator())
        left.animate().translationX(if (towardsRight) -width else width).setDuration(SLIDE_MS)
            .setInterpolator(FastOutSlowInInterpolator()).withEndAction {
                if (shown !== left) left.visibility = View.GONE
                left.translationX = 0f
            }
    }

    private fun whenDrawn(screen: View, then: () -> Unit) {
        var done = false
        val once = { if (!done) { done = true; then() } }
        // A hidden WebView stops drawing; this callback fires once its page is on screen again.
        screen.webView()?.postVisualStateCallback(0, object : WebView.VisualStateCallback() {
            override fun onComplete(requestId: Long) = once()
        })
        screen.postDelayed(once, LONGEST_WAIT_MS)
    }

    private fun View.webView(): WebView? = when (this) {
        is WebView -> this
        is ViewGroup -> children.firstNotNullOfOrNull { it.webView() }
        else -> null
    }

    private companion object {
        const val SLIDE_MS = 280L
        const val LONGEST_WAIT_MS = 400L
    }
}
