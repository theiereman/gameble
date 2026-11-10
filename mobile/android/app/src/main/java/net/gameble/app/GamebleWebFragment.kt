package net.gameble.app

import android.net.Uri
import android.os.Bundle
import android.view.HapticFeedbackConstants
import android.view.MotionEvent
import android.view.View
import androidx.navigation.NavOptions
import androidx.navigation.navOptions
import androidx.swiperefreshlayout.widget.SwipeRefreshLayout
import com.google.android.material.appbar.AppBarLayout
import dev.hotwire.core.turbo.config.pullToRefreshEnabled
import dev.hotwire.core.turbo.errors.VisitError
import dev.hotwire.core.turbo.visit.VisitAction
import dev.hotwire.core.turbo.visit.VisitProposal
import dev.hotwire.core.turbo.webview.HotwireWebView
import dev.hotwire.navigation.destinations.HotwireDestination
import dev.hotwire.navigation.destinations.HotwireDestinationDeepLink
import dev.hotwire.navigation.fragments.HotwireWebFragment
import dev.hotwire.navigation.R as HotwireR
import dev.hotwire.navigation.routing.Router

@HotwireDestinationDeepLink(uri = "hotwire://fragment/web")
class GamebleWebFragment : HotwireWebFragment() {
    var pageReady = false
        private set

    var dialogOpen = false
        private set

    var pullHeld = false
        set(held) {
            field = held
            if (held) pullGesture.cancel()?.let(::showPull)
        }

    private val pullGesture by lazy { PullGesture(PULL_DISTANCE_DP * resources.displayMetrics.density) }
    private var refreshing = false
    private var attachedWebView: HotwireWebView? = null

    private val host: GamebleActivity?
        get() = activity as? GamebleActivity

    fun dialogChanged(open: Boolean) {
        dialogOpen = open
        host?.screenDialogChanged(navigator, open)
    }

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)
        hideAppBar()
        view.findViewById<SwipeRefreshLayout>(HotwireR.id.hotwire_webView_container)
            ?.setOnChildScrollUpCallback { _, _ -> true }
    }

    override fun onStart() {
        super.onStart()
        host?.screenOnView(navigator, dialogOpen)
    }

    // A WebView rasters only what is on screen; a tab sliding in would otherwise paint itself as it arrives.
    override fun onWebViewAttached(webView: HotwireWebView) {
        super.onWebViewAttached(webView)
        attachedWebView = webView
        webView.settings.offscreenPreRaster = true
        webView.setOnScrollChangeListener { _, _, scrollY, _, _ -> host?.screenScrolled(navigator, scrollY) }
        webView.setOnTouchListener { _, event ->
            if (event.actionMasked == MotionEvent.ACTION_DOWN) host?.screenTouched(navigator)
            followPull(webView, event)
            false
        }
    }

    private fun followPull(webView: HotwireWebView, event: MotionEvent) {
        if (!pathProperties.pullToRefreshEnabled || refreshing) return
        val atTop = webView.scrollY == 0
        val change = when (event.actionMasked) {
            MotionEvent.ACTION_DOWN -> {
                pullGesture.down(event.y, atTop)
                null
            }
            MotionEvent.ACTION_MOVE -> pullGesture.move(event.y, atTop, pullHeld || webView.elementTouchPreventsPullsToRefresh)
            MotionEvent.ACTION_UP -> pullGesture.up()
            MotionEvent.ACTION_CANCEL -> pullGesture.cancel()
            else -> null
        }
        change?.let(::showPull)
    }

    private fun showPull(change: PullGesture.Change) {
        when (change) {
            is PullGesture.Change.Pulled -> {
                if (change.reachedFull) view?.performHapticFeedback(HapticFeedbackConstants.CLOCK_TICK)
                host?.screenPulled(navigator, change.progress)
            }
            is PullGesture.Change.LetGo -> if (change.refresh) startRefresh() else host?.screenPulled(navigator, 0f)
        }
    }

    private fun startRefresh() {
        refreshing = true
        host?.screenRefreshing(navigator, true)
        refreshInPlace()
        view?.postDelayed(::finishRefresh, REFRESH_TIMEOUT_MS)
    }

    // Hotwire's refresh cold-boots the page behind its progress view; a Turbo visit keeps the screen until the new one renders.
    private fun refreshInPlace() {
        val webView = attachedWebView ?: return refresh(displayProgress = false)
        webView.evaluateJavascript(REFRESH_IN_PLACE_SCRIPT) { refreshed ->
            if (refreshed != "true" && refreshing) refresh(displayProgress = false)
        }
    }

    private fun finishRefresh() {
        if (!refreshing) return
        refreshing = false
        host?.screenRefreshing(navigator, false)
    }

    override fun onWebViewDetached(webView: HotwireWebView) {
        attachedWebView = null
        webView.setOnScrollChangeListener(null)
        webView.setOnTouchListener(null)
        super.onWebViewDetached(webView)
    }

    override fun onVisitRendered(location: String) {
        super.onVisitRendered(location)
        pageReady = true
        finishRefresh()
        host?.screenArrived(requireView())
    }

    override fun onVisitErrorReceived(location: String, error: VisitError) {
        super.onVisitErrorReceived(location, error)
        finishRefresh()
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

private const val REFRESH_TIMEOUT_MS = 12_000L
private const val REFRESH_IN_PLACE_SCRIPT =
    "window.Turbo ? (Turbo.visit(location.href, { action: 'replace' }), true) : false"
