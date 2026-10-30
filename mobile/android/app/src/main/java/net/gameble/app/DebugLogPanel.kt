package net.gameble.app

import android.app.Activity
import android.content.ClipData
import android.content.ClipboardManager
import android.graphics.Color
import android.graphics.Typeface
import android.os.Build
import android.os.Process
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.ViewGroup.LayoutParams.MATCH_PARENT
import android.view.ViewGroup.LayoutParams.WRAP_CONTENT
import android.webkit.WebSettings
import android.webkit.WebView
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import kotlin.concurrent.thread

class DebugLogPanel(private val activity: Activity) {
    private val lines = ArrayDeque<String>()
    private val log = TextView(activity).apply {
        typeface = Typeface.MONOSPACE
        textSize = 9f
        setTextColor(Color.GREEN)
        setPadding(12, 12, 12, 12)
    }
    private val scroll = ScrollView(activity).apply {
        setBackgroundColor(0xDD000000.toInt())
        addView(log)
    }
    private val panel = LinearLayout(activity).apply {
        orientation = LinearLayout.VERTICAL
        gravity = Gravity.END
        visibility = View.GONE
    }
    private val recentCornerTaps = ArrayDeque<Long>()

    fun attachTo(container: FrameLayout) {
        panel.addView(buttons(), LinearLayout.LayoutParams(WRAP_CONTENT, WRAP_CONTENT))
        panel.addView(scroll, LinearLayout.LayoutParams(MATCH_PARENT, container.resources.displayMetrics.heightPixels / 2))
        container.addView(panel, FrameLayout.LayoutParams(MATCH_PARENT, WRAP_CONTENT, Gravity.BOTTOM))
        environment().forEach(::append)
        thread(isDaemon = true) { tailLogcat() }
    }

    private fun environment() = listOf(
        "root: ${Gameble.ROOT_URL}",
        "start: ${Gameble.url()}",
        "android: ${Build.VERSION.RELEASE} (sdk ${Build.VERSION.SDK_INT}) ${Build.MANUFACTURER} ${Build.MODEL}",
        "webview: ${WebView.getCurrentWebViewPackage()?.let { "${it.packageName} ${it.versionName}" }}",
        "user agent: ${WebSettings.getDefaultUserAgent(activity)}"
    )

    fun onTouch(event: MotionEvent) {
        if (event.actionMasked != MotionEvent.ACTION_DOWN || !inTopLeftCorner(event)) return
        recentCornerTaps.addLast(event.eventTime)
        while (event.eventTime - recentCornerTaps.first() > TAPS_WINDOW_MS) recentCornerTaps.removeFirst()
        if (recentCornerTaps.size >= TAPS_TO_TOGGLE) {
            recentCornerTaps.clear()
            toggle()
        }
    }

    private fun inTopLeftCorner(event: MotionEvent): Boolean {
        val screen = activity.resources.displayMetrics
        return event.rawX < screen.widthPixels * 0.4f && event.rawY < screen.heightPixels * 0.2f
    }

    private fun toggle() {
        panel.visibility = if (panel.visibility == View.VISIBLE) View.GONE else View.VISIBLE
    }

    private fun buttons() = LinearLayout(activity).apply {
        addView(button(R.string.debug_log_hide) { toggle() })
        addView(button(R.string.debug_log_copy) { copy() })
    }

    private fun button(label: Int, onClick: () -> Unit) = TextView(activity).apply {
        setText(label)
        setTextColor(Color.WHITE)
        setBackgroundColor(0xCCB00020.toInt())
        setPadding(24, 16, 24, 16)
        setOnClickListener { onClick() }
    }

    private fun copy() {
        val clipboard = activity.getSystemService(ClipboardManager::class.java)
        clipboard.setPrimaryClip(ClipData.newPlainText("gameble log", lines.joinToString("\n")))
    }

    private fun tailLogcat() {
        val filters = arrayOf("Hotwire-Core:D", "Hotwire-Navigation:D", "Hotwire-Bridge:D", "chromium:I", "AndroidRuntime:E", "*:S")
        runCatching {
            ProcessBuilder("logcat", "-v", "time", "--pid=${Process.myPid()}", *filters)
                .redirectErrorStream(true)
                .start()
                .inputStream.bufferedReader()
                .forEachLine { line -> activity.runOnUiThread { append(line) } }
        }.onFailure { error -> activity.runOnUiThread { append("logcat failed: $error") } }
    }

    private fun append(line: String) {
        lines.addLast(line)
        while (lines.size > MAX_LINES) lines.removeFirst()
        log.text = lines.joinToString("\n")
        scroll.post { scroll.fullScroll(View.FOCUS_DOWN) }
    }

    private companion object {
        const val MAX_LINES = 400
        const val TAPS_TO_TOGGLE = 5
        const val TAPS_WINDOW_MS = 3000L
    }
}
