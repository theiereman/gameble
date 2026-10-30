package net.gameble.app

import android.os.Bundle
import android.view.View
import com.google.android.material.appbar.AppBarLayout
import dev.hotwire.navigation.destinations.HotwireDestinationDeepLink
import dev.hotwire.navigation.fragments.HotwireWebFragment

@HotwireDestinationDeepLink(uri = "hotwire://fragment/web")
class GamebleWebFragment : HotwireWebFragment() {
    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)
        hideAppBar()
    }

    private fun hideAppBar() {
        val toolbar = toolbarForNavigation() ?: return
        (toolbar.parent as? AppBarLayout ?: toolbar).visibility = View.GONE
    }
}
