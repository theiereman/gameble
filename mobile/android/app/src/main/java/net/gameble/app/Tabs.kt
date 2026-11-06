package net.gameble.app

import android.content.Context
import dev.hotwire.navigation.navigator.NavigatorConfiguration
import dev.hotwire.navigation.tabs.HotwireBottomTab

object Tabs {
    class Destination(val tab: Int?, val atRoot: Boolean)

    private val NAMES = listOf("hub", "capsule", "sets", "friends", "trades")
    private val PATHS = listOf("", "/booster", "/library", "/friends", "/trades")
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
}
