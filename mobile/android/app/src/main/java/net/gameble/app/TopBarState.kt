package net.gameble.app

import android.content.Context
import kotlinx.serialization.Serializable

@Serializable
data class TopBarReport(
    val standard: String = "",
    val special: String = "",
    val bell: String = "",
    val menuBadge: String = "",
    val capsules: String = "",
    val friends: String = "",
    val trades: String = "",
    val avatar: String = ""
)

object TopBarState {
    private const val PREFERENCES = "top_bar"

    private val listeners = mutableSetOf<(TopBarReport) -> Unit>()
    private val labelsByLocation = mutableMapOf<String, String>()
    private var known: TopBarReport? = null

    fun current(context: Context): TopBarReport =
        known ?: load(context).also { known = it }

    fun listen(context: Context, listener: (TopBarReport) -> Unit) {
        listeners += listener
        listener(current(context))
    }

    fun stopListening(listener: (TopBarReport) -> Unit) {
        listeners -= listener
    }

    fun accept(context: Context, report: TopBarReport) {
        val state = report.copy(avatar = report.avatar.ifEmpty { current(context).avatar })
        if (state == current(context)) return
        known = state
        save(context, state)
        listeners.forEach { it(state) }
    }

    fun clear(context: Context) {
        known = TopBarReport()
        preferences(context).edit().clear().apply()
    }

    fun rememberLabel(location: String, label: String) {
        labelsByLocation[location] = label
    }

    fun label(location: String?): String? = location?.let { labelsByLocation[it] }

    private fun load(context: Context): TopBarReport {
        val saved = preferences(context)
        return TopBarReport(
            standard = saved.getString("standard", "").orEmpty(),
            special = saved.getString("special", "").orEmpty(),
            bell = saved.getString("bell", "").orEmpty(),
            menuBadge = saved.getString("menu_badge", "").orEmpty(),
            capsules = saved.getString("capsules", "").orEmpty(),
            friends = saved.getString("friends", "").orEmpty(),
            trades = saved.getString("trades", "").orEmpty(),
            avatar = saved.getString("avatar", "").orEmpty()
        )
    }

    private fun save(context: Context, state: TopBarReport) {
        preferences(context).edit()
            .putString("standard", state.standard)
            .putString("special", state.special)
            .putString("bell", state.bell)
            .putString("menu_badge", state.menuBadge)
            .putString("capsules", state.capsules)
            .putString("friends", state.friends)
            .putString("trades", state.trades)
            .putString("avatar", state.avatar)
            .apply()
    }

    private fun preferences(context: Context) =
        context.applicationContext.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE)
}

class TopBarScroll {
    private var anchor = 0f

    fun reset(position: Float) {
        anchor = position
    }

    fun barShownAfterMovingTo(position: Float): Boolean? = when {
        position < ALWAYS_SHOWN_ABOVE -> anchored(position, true)
        position > anchor + MARGIN -> anchored(position, false)
        position < anchor - MARGIN -> anchored(position, true)
        else -> null
    }

    private fun anchored(position: Float, shown: Boolean): Boolean {
        anchor = position
        return shown
    }

    private companion object {
        const val ALWAYS_SHOWN_ABOVE = 16f
        const val MARGIN = 4f
    }
}
