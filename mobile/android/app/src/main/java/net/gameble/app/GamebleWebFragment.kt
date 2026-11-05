package net.gameble.app

import android.net.Uri
import android.os.Bundle
import android.view.View
import androidx.navigation.NavOptions
import androidx.navigation.navOptions
import com.google.android.material.appbar.AppBarLayout
import dev.hotwire.core.turbo.visit.VisitAction
import dev.hotwire.navigation.destinations.HotwireDestination
import dev.hotwire.navigation.destinations.HotwireDestinationDeepLink
import dev.hotwire.navigation.fragments.HotwireWebFragment

@HotwireDestinationDeepLink(uri = "hotwire://fragment/web")
class GamebleWebFragment : HotwireWebFragment() {
    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)
        hideAppBar()
    }

    // The same screen with other parameters (a filter chosen in a sheet) swaps in place, as Turbo does on the web.
    override fun customNavigationOptions(
        newLocation: String,
        newPathProperties: HashMap<String, Any>,
        action: VisitAction
    ): NavOptions? = if (Uri.parse(newLocation).path == Uri.parse(location).path) navOptions {} else null
}

internal fun HotwireDestination.hideAppBar() {
    val toolbar = toolbarForNavigation() ?: return
    (toolbar.parent as? AppBarLayout ?: toolbar).visibility = View.GONE
}
