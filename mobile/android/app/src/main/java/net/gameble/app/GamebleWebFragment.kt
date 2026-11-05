package net.gameble.app

import android.net.Uri
import android.os.Bundle
import android.view.View
import androidx.navigation.NavOptions
import androidx.navigation.navOptions
import com.google.android.material.appbar.AppBarLayout
import dev.hotwire.core.turbo.errors.VisitError
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

    override fun onVisitRendered(location: String) {
        super.onVisitRendered(location)
        (activity as? MainActivity)?.screenArrived(requireView())
    }

    override fun onVisitErrorReceived(location: String, error: VisitError) {
        super.onVisitErrorReceived(location, error)
        (activity as? MainActivity)?.screenArrived(requireView())
    }

    // The same screen with other parameters (a filter chosen in a sheet) swaps in place, as Turbo does on the web;
    // another screen moves along the shared axis (ScreenTransition); a sheet keeps the library's rise.
    override fun customNavigationOptions(
        newLocation: String,
        newPathProperties: HashMap<String, Any>,
        action: VisitAction
    ): NavOptions? {
        if (newPathProperties["context"] == "modal") return null
        val inPlace = action == VisitAction.REPLACE || Uri.parse(newLocation).path == Uri.parse(location).path
        if (!inPlace) (activity as? MainActivity)?.leaveScreen(forward = newLocation != navigator.previousLocation)
        return navOptions {}
    }
}

internal fun HotwireDestination.hideAppBar() {
    val toolbar = toolbarForNavigation() ?: return
    (toolbar.parent as? AppBarLayout ?: toolbar).visibility = View.GONE
}
