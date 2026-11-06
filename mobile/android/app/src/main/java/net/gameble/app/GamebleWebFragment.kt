package net.gameble.app

import android.net.Uri
import android.os.Bundle
import android.view.MotionEvent
import android.view.View
import androidx.navigation.NavOptions
import androidx.navigation.navOptions
import com.google.android.material.appbar.AppBarLayout
import dev.hotwire.core.turbo.errors.VisitError
import dev.hotwire.core.turbo.visit.VisitAction
import dev.hotwire.core.turbo.visit.VisitProposal
import dev.hotwire.core.turbo.webview.HotwireWebView
import dev.hotwire.navigation.destinations.HotwireDestination
import dev.hotwire.navigation.destinations.HotwireDestinationDeepLink
import dev.hotwire.navigation.fragments.HotwireWebFragment
import dev.hotwire.navigation.routing.Router

@HotwireDestinationDeepLink(uri = "hotwire://fragment/web")
class GamebleWebFragment : HotwireWebFragment() {
    var pageReady = false
        private set

    var dialogOpen = false
        private set

    private val host: GamebleActivity?
        get() = activity as? GamebleActivity

    fun dialogChanged(open: Boolean) {
        dialogOpen = open
        host?.screenDialogChanged(navigator, open)
    }

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)
        hideAppBar()
    }

    override fun onStart() {
        super.onStart()
        host?.screenOnView(navigator, dialogOpen)
    }

    // A WebView rasters only what is on screen; a tab sliding in would otherwise paint itself as it arrives.
    override fun onWebViewAttached(webView: HotwireWebView) {
        super.onWebViewAttached(webView)
        webView.settings.offscreenPreRaster = true
        webView.setOnScrollChangeListener { _, _, scrollY, _, _ -> host?.screenScrolled(navigator, scrollY) }
        webView.setOnTouchListener { _, event ->
            if (event.actionMasked == MotionEvent.ACTION_DOWN) host?.screenTouched(navigator)
            false
        }
    }

    override fun onWebViewDetached(webView: HotwireWebView) {
        webView.setOnScrollChangeListener(null)
        webView.setOnTouchListener(null)
        super.onWebViewDetached(webView)
    }

    override fun onVisitRendered(location: String) {
        super.onVisitRendered(location)
        pageReady = true
        host?.screenArrived(requireView())
    }

    override fun onVisitErrorReceived(location: String, error: VisitError) {
        super.onVisitErrorReceived(location, error)
        host?.screenArrived(requireView())
    }

    override fun customRouteDecision(proposal: VisitProposal): Router.Decision? {
        val path = Gameble.pathOf(proposal.location) ?: return null
        val tab = Tabs.destination(path).tab ?: return null
        val shell = host ?: return null
        if (tab == Tabs.index(navigator.configuration.name)) return null
        requireView().post { shell.openDestination(path) }
        return Router.Decision.CANCEL
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
        if (!inPlace) host?.leaveScreen(forward = newLocation != navigator.previousLocation)
        return navOptions {}
    }
}

internal fun HotwireDestination.hideAppBar() {
    val toolbar = toolbarForNavigation() ?: return
    (toolbar.parent as? AppBarLayout ?: toolbar).visibility = View.GONE
}
