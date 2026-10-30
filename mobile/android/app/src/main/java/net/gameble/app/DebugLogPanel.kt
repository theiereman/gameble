package net.gameble.app

import android.app.Activity
import android.content.ClipData
import android.content.ClipboardManager
import android.graphics.Color
import android.graphics.Typeface
import android.os.Build
import android.os.Process
import android.view.Gravity
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

    fun attachTo(container: FrameLayout) {
        container.addView(scroll, FrameLayout.LayoutParams(MATCH_PARENT, container.resources.displayMetrics.heightPixels / 2, Gravity.BOTTOM))
        container.addView(buttons(), FrameLayout.LayoutParams(WRAP_CONTENT, WRAP_CONTENT, Gravity.TOP or Gravity.END))
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

    private fun buttons() = LinearLayout(activity).apply {
        addView(button(R.string.debug_log_toggle) { scroll.visibility = if (scroll.isShown) View.GONE else View.VISIBLE })
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
    }
}
