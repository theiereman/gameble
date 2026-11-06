package net.gameble.app

import android.content.Context
import dev.hotwire.navigation.navigator.NavigatorConfiguration
import dev.hotwire.navigation.tabs.HotwireBottomTab

object Tabs {
    class Destination(val tab: Int?, val atRoot: Boolean)

    private val PATHS = listOf("", "/booster", "/library", "/friends", "/trades")
    private val LOCALE = Regex("^/(en|fr)(?=[/?#]|$)")

    fun destination(path: String): Destination {
        val location = path.replace(LOCALE, "")
        val bare = location.substringBefore('?').substringBefore('#').trimEnd('/')
        val tab = PATHS.indexOfFirst { bare == it || (it.isNotEmpty() && bare.startsWith("$it/")) }.takeIf { it >= 0 }
        return Destination(tab, atRoot = tab != null && location.trimEnd('/') == PATHS[tab])
    }

    fun all(context: Context): List<HotwireBottomTab> = listOf(
        tab(context, "hub", R.string.tab_hub, R.drawable.ic_tab_hub, "", R.id.hub_host),
        tab(context, "capsule", R.string.tab_capsule, R.drawable.ic_tab_capsule, "/booster", R.id.capsule_host),
        tab(context, "sets", R.string.tab_sets, R.drawable.ic_tab_sets, "/library", R.id.sets_host),
        tab(context, "friends", R.string.tab_friends, R.drawable.ic_tab_friends, "/friends", R.id.friends_host),
        tab(context, "trades", R.string.tab_trades, R.drawable.ic_tab_trades, "/trades", R.id.trades_host)
    )

    private fun tab(context: Context, name: String, title: Int, icon: Int, path: String, host: Int) = HotwireBottomTab(
        title = context.getString(title),
        iconResId = icon,
        configuration = NavigatorConfiguration(name = name, startLocation = Gameble.url(path), navigatorHostId = host)
    )
}
