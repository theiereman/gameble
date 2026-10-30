package net.gameble.app

import android.content.Context
import dev.hotwire.navigation.navigator.NavigatorConfiguration
import dev.hotwire.navigation.tabs.HotwireBottomTab

object Tabs {
    fun all(context: Context): List<HotwireBottomTab> = listOf(
        tab(context, "bridge", R.string.tab_bridge, R.drawable.ic_tab_bridge, "", R.id.bridge_host),
        tab(context, "capsule", R.string.tab_capsule, R.drawable.ic_tab_capsule, "/booster", R.id.capsule_host),
        tab(context, "collection", R.string.tab_collection, R.drawable.ic_tab_collection, "/library", R.id.collection_host),
        tab(context, "trades", R.string.tab_trades, R.drawable.ic_tab_trades, "/trades", R.id.trades_host),
        tab(context, "more", R.string.tab_more, R.drawable.ic_tab_more, "/more", R.id.more_host)
    )

    private fun tab(context: Context, name: String, title: Int, icon: Int, path: String, host: Int) = HotwireBottomTab(
        title = context.getString(title),
        iconResId = icon,
        configuration = NavigatorConfiguration(name = name, startLocation = Gameble.url(path), navigatorHostId = host)
    )
}
