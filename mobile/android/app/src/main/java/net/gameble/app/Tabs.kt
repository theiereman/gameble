package net.gameble.app

import android.content.Context
import dev.hotwire.navigation.navigator.NavigatorConfiguration
import dev.hotwire.navigation.tabs.HotwireBottomTab

object Tabs {
    fun all(context: Context): List<HotwireBottomTab> = listOf(
        tab(context, "capsule", R.string.tab_capsule, R.drawable.ic_tab_capsule, "/booster", R.id.capsule_host),
        tab(context, "sets", R.string.tab_sets, R.drawable.ic_tab_sets, "/library", R.id.sets_host),
        tab(context, "social", R.string.tab_social, R.drawable.ic_tab_social, "/social", R.id.social_host),
        tab(context, "me", R.string.tab_me, R.drawable.ic_tab_me, "/me", R.id.me_host)
    )

    private fun tab(context: Context, name: String, title: Int, icon: Int, path: String, host: Int) = HotwireBottomTab(
        title = context.getString(title),
        iconResId = icon,
        configuration = NavigatorConfiguration(name = name, startLocation = Gameble.url(path), navigatorHostId = host)
    )
}
