package net.gameble.app

import android.content.Context
import androidx.core.content.ContextCompat
import com.google.android.material.bottomnavigation.BottomNavigationView
import dev.hotwire.navigation.navigator.NavigatorConfiguration
import dev.hotwire.navigation.tabs.HotwireBottomTab

object Tabs {
    class Destination(val tab: Int?, val atRoot: Boolean)

    private val NAMES = listOf("hub", "capsule", "sets", "friends", "trades")
    private val PATHS = listOf("", "/booster", "/library", "/friends", "/trades")
    private const val CAPSULE = 1
    private const val FRIENDS = 3
    private const val TRADES = 4
    private val LOCALE = Regex("^/(en|fr)(?=[/?#]|$)")

    fun destination(path: String): Destination {
        val location = path.replace(LOCALE, "")
        val bare = location.substringBefore('?').substringBefore('#').trimEnd('/')
        val tab = PATHS.indexOfFirst { bare == it || (it.isNotEmpty() && bare.startsWith("$it/")) }.takeIf { it >= 0 }
        return Destination(tab, atRoot = tab != null && location.trimEnd('/') == PATHS[tab])
    }

    fun index(navigatorName: String): Int? = NAMES.indexOf(navigatorName).takeIf { it >= 0 }

    fun all(context: Context): List<HotwireBottomTab> = listOf(
        tab(context, 0, R.string.tab_hub, R.drawable.ic_tab_hub, R.id.hub_host),
        tab(context, 1, R.string.tab_capsule, R.drawable.ic_tab_capsule, R.id.capsule_host),
        tab(context, 2, R.string.tab_sets, R.drawable.ic_tab_sets, R.id.sets_host),
        tab(context, 3, R.string.tab_friends, R.drawable.ic_tab_friends, R.id.friends_host),
        tab(context, 4, R.string.tab_trades, R.drawable.ic_tab_trades, R.id.trades_host)
    )

    private fun tab(context: Context, index: Int, title: Int, icon: Int, host: Int) = HotwireBottomTab(
        title = context.getString(title),
        iconResId = icon,
        configuration = NavigatorConfiguration(name = NAMES[index], startLocation = Gameble.url(PATHS[index]), navigatorHostId = host)
    )

    fun showBadges(report: TopBarReport, bar: BottomNavigationView) {
        badge(bar, CAPSULE, report.capsules, R.color.primary, R.color.on_primary)
        badge(bar, FRIENDS, report.friends, R.color.friends, R.color.on_friends)
        badge(bar, TRADES, report.trades, R.color.alert, R.color.on_alert)
    }

    private fun badge(bar: BottomNavigationView, index: Int, value: String, background: Int, text: Int) {
        if (index >= bar.menu.size()) return
        val item = bar.menu.getItem(index).itemId
        val count = value.filter(Char::isDigit).toIntOrNull()?.takeIf { it > 0 } ?: return bar.removeBadge(item)
        bar.getOrCreateBadge(item).apply {
            backgroundColor = ContextCompat.getColor(bar.context, background)
            badgeTextColor = ContextCompat.getColor(bar.context, text)
            number = count
        }
    }
}
