package net.gameble.app

import android.content.Context
import android.graphics.BitmapFactory
import android.graphics.drawable.BitmapDrawable
import android.util.AttributeSet
import android.util.Base64
import android.view.View
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.TextView
import androidx.core.view.isVisible
import androidx.core.view.updatePadding
import androidx.interpolator.view.animation.FastOutSlowInInterpolator
import java.util.Locale

class TopBarView @JvmOverloads constructor(context: Context, attrs: AttributeSet? = null) : FrameLayout(context, attrs) {
    sealed interface Left {
        data object Home : Left
        data class Back(val label: String) : Left
    }

    var onBack: () -> Unit = {}
    var onCapsules: () -> Unit = {}
    var onBell: () -> Unit = {}
    var onMenu: () -> Unit = {}

    var onScreen = true
        private set

    private var shownAvatar = ""

    private val content: View
    private val home: View
    private val back: View
    private val backLabel: TextView
    private val standard: TextView
    private val special: TextView
    private val specialIcon: View
    private val bellBadge: TextView
    private val menuBadge: TextView
    private val avatar: ImageView
    private val capsules: View
    private val bell: View
    private val menu: View
    private val pullConsole: PullConsoleView

    init {
        inflate(context, R.layout.view_top_bar, this)
        setBackgroundResource(R.color.steam_bar)
        isClickable = true
        content = findViewById(R.id.top_bar_content)
        home = findViewById(R.id.top_bar_home)
        back = findViewById(R.id.top_bar_back)
        backLabel = findViewById(R.id.top_bar_back_label)
        standard = findViewById(R.id.top_bar_standard)
        special = findViewById(R.id.top_bar_special)
        specialIcon = findViewById(R.id.top_bar_special_icon)
        bellBadge = findViewById(R.id.top_bar_bell_badge)
        menuBadge = findViewById(R.id.top_bar_menu_badge)
        avatar = findViewById(R.id.top_bar_avatar)
        capsules = findViewById(R.id.top_bar_capsules)
        bell = findViewById(R.id.top_bar_bell)
        menu = findViewById(R.id.top_bar_menu)
        pullConsole = findViewById(R.id.top_bar_pull_console)
        back.setOnClickListener { onBack() }
        capsules.setOnClickListener { onCapsules() }
        bell.setOnClickListener { onBell() }
        menu.setOnClickListener { onMenu() }
    }

    fun applyStatusInset(top: Int) = updatePadding(top = top)

    fun showPull(progress: Float) = pullConsole.showProgress(progress)

    fun showRefreshing(refreshing: Boolean) = if (refreshing) pullConsole.startSweep() else pullConsole.hide()

    fun show(left: Left) {
        home.isVisible = left is Left.Home
        back.isVisible = left is Left.Back
        if (left is Left.Back) {
            backLabel.text = left.label.uppercase(Locale.getDefault())
            back.contentDescription = context.getString(R.string.top_bar_back_to, left.label)
        }
    }

    fun render(state: TopBarReport) {
        standard.text = state.standard
        special.text = state.special
        val noneSpecial = state.special.isEmpty() || state.special == "0"
        special.alpha = if (noneSpecial) MUTED else 1f
        specialIcon.alpha = if (noneSpecial) MUTED else 1f
        bellBadge.text = state.bell
        bellBadge.isVisible = state.bell.isNotEmpty()
        menuBadge.text = state.menuBadge
        menuBadge.isVisible = state.menuBadge.isNotEmpty()
        renderAvatar(state.avatar)
        describeControls(state)
    }

    private fun describeControls(state: TopBarReport) {
        capsules.contentDescription = if (state.standard.isEmpty()) {
            context.getString(R.string.top_bar_capsules)
        } else {
            context.getString(R.string.top_bar_capsules_counts, state.standard, state.special)
        }
        bell.contentDescription = if (state.bell.isEmpty()) {
            context.getString(R.string.top_bar_bell)
        } else {
            context.getString(R.string.top_bar_bell_unread, state.bell)
        }
        menu.contentDescription = if (state.menuBadge.isEmpty()) {
            context.getString(R.string.top_bar_menu)
        } else {
            context.getString(R.string.top_bar_menu_rewards, state.menuBadge)
        }
    }

    fun setShown(shown: Boolean) {
        if (onScreen == shown) return
        onScreen = shown
        animate().translationY(if (shown) 0f else -content.height.toFloat())
            .setDuration(SLIDE_MS)
            .setInterpolator(FastOutSlowInInterpolator())
    }

    fun setDimmed(dimmed: Boolean) {
        content.alpha = if (dimmed) DIMMED else 1f
        listOf(back, capsules, bell, menu).forEach { it.isEnabled = !dimmed }
        if (dimmed) setShown(true)
    }

    private fun renderAvatar(source: String) {
        if (source == shownAvatar) return
        shownAvatar = source
        val bytes = runCatching { Base64.decode(source.substringAfter(','), Base64.DEFAULT) }.getOrNull() ?: return
        val bitmap = BitmapFactory.decodeByteArray(bytes, 0, bytes.size)
        avatar.setImageDrawable(bitmap?.let { BitmapDrawable(resources, it).apply { isFilterBitmap = false } })
    }

    private companion object {
        const val MUTED = 0.55f
        const val DIMMED = 0.4f
        const val SLIDE_MS = 200L
    }
}
