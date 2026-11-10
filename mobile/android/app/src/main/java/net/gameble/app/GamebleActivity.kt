package net.gameble.app

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import android.view.View
import android.view.ViewGroup
import androidx.activity.OnBackPressedCallback
import androidx.activity.result.contract.ActivityResultContracts
import androidx.core.content.ContextCompat
import androidx.core.graphics.Insets
import androidx.core.view.ViewCompat
import androidx.core.view.WindowInsetsCompat
import androidx.core.view.updateLayoutParams
import com.google.firebase.messaging.FirebaseMessaging
import androidx.lifecycle.Lifecycle
import dev.hotwire.navigation.activities.HotwireActivity
import dev.hotwire.navigation.navigator.Navigator

abstract class GamebleActivity : HotwireActivity() {
    private var pendingGrant: ((String?) -> Unit)? = null
    private lateinit var screenTransition: ScreenTransition
    private var topBar: TopBarView? = null
    private var pullConsole: PullConsoleView? = null
    private val topBarScroll = TopBarScroll()
    private var playerTouchedScreen = false
    private val renderTopBar: (TopBarReport) -> Unit = { topBar?.render(it) }
    protected var tabsShown = false

    private val notificationPermission = registerForActivityResult(ActivityResultContracts.RequestPermission()) { granted ->
        if (granted) fetchPushToken() else finishGrant(null)
    }

    protected open val rootBackLabel: String? get() = null

    abstract fun openDestination(path: String)

    protected abstract fun currentScreen(): View

    protected open fun leaveRoot(): Boolean = false

    open fun showTabs(shown: Boolean) = Unit

    protected fun setUpScreens() {
        topBar = findViewById<TopBarView>(R.id.top_bar).apply {
            onBack = { goBack() }
            onCapsules = { openDestination(CAPSULES_PATH) }
            onBell = { togglePanel("bell") }
            onMenu = { togglePanel("menu") }
        }
        pullConsole = findViewById(R.id.pull_console)
        fitScreensBetweenStatusBarAndTabs()
        screenTransition = ScreenTransition(findViewById(R.id.screens))
        onBackPressedDispatcher.addCallback(this, backWithTransition)
    }

    override fun onStart() {
        super.onStart()
        if (topBar != null) TopBarState.listen(this, renderTopBar)
    }

    override fun onStop() {
        TopBarState.stopListening(renderTopBar)
        super.onStop()
    }

    override fun onRestart() {
        super.onRestart()
        announceScreenShown()
    }

    fun screenOnView(
        navigator: Navigator,
        dialogOpen: Boolean = (navigator.takeIf { it.isReady() }?.currentDestination as? GamebleWebFragment)?.dialogOpen == true
    ) {
        if (navigator !== delegate.currentNavigator) return
        showLeftSide(navigator)
        setTopBarShown(true)
        topBar?.setDimmed(dialogOpen)
        playerTouchedScreen = false
    }

    fun screenTouched(navigator: Navigator) {
        if (navigator !== delegate.currentNavigator) return
        playerTouchedScreen = true
        topBarScroll.reset(navigator.session.webView.scrollY / resources.displayMetrics.density)
    }

    fun screenDialogChanged(navigator: Navigator, open: Boolean) {
        if (navigator === delegate.currentNavigator) topBar?.setDimmed(open)
    }

    fun screenLabelsChanged() {
        delegate.currentNavigator?.let(::showLeftSide)
    }

    private fun showLeftSide(navigator: Navigator) {
        val backLabel = if (navigator.isAtStartDestination()) {
            rootBackLabel
        } else {
            TopBarState.label(navigator.previousLocation) ?: getString(R.string.top_bar_back)
        }
        topBar?.show(backLabel?.let { TopBarView.Left.Back(it) } ?: TopBarView.Left.Home)
    }

    fun screenPulled(navigator: Navigator, progress: Float) {
        if (navigator !== delegate.currentNavigator) return
        if (progress > 0f) setTopBarShown(true)
        pullConsole?.showPull(progress)
    }

    fun screenRefreshing(navigator: Navigator, refreshing: Boolean) {
        if (navigator !== delegate.currentNavigator && refreshing) return
        if (refreshing) setTopBarShown(true)
        pullConsole?.showRefreshing(refreshing)
    }

    fun screenScrolled(navigator: Navigator, scrollY: Int) {
        if (navigator !== delegate.currentNavigator || !playerTouchedScreen) return
        topBarScroll.barShownAfterMovingTo(scrollY / resources.displayMetrics.density)?.let(::setTopBarShown)
    }

    private fun setTopBarShown(shown: Boolean) {
        val bar = topBar ?: return
        if (bar.onScreen == shown) return
        if (!shown) sendPanel(null)
        bar.setShown(shown)
    }

    fun topBarReported(navigator: Navigator, report: TopBarReport) {
        val onView = navigator === delegate.currentNavigator && lifecycle.currentState.isAtLeast(Lifecycle.State.STARTED)
        if (onView) TopBarState.accept(this, report)
    }

    private fun togglePanel(panel: String) {
        val screen = delegate.currentNavigator?.takeIf { it.isReady() }?.currentDestination as? GamebleWebFragment
        if (screen?.pageReady == true) sendPanel(panel)
    }

    private fun sendPanel(panel: String?) {
        val wanted = panel?.let { "'$it'" } ?: "null"
        delegate.currentNavigator?.session?.webView?.evaluateJavascript(
            "window.dispatchEvent(new CustomEvent('gameble:top-bar-panel', { detail: { panel: $wanted } }))",
            null
        )
    }

    protected fun announceScreenShown() {
        delegate.currentNavigator?.session?.webView?.evaluateJavascript(SCREEN_SHOWN, null)
    }

    protected fun dropScreenTransition() = screenTransition.drop()

    fun leaveScreen(forward: Boolean) {
        screenTransition.leave(window, currentScreen(), forward)
    }

    fun screenArrived(page: View) {
        if (page.parent != null && isInside(page, currentScreen())) screenTransition.arrived(page)
    }

    private fun isInside(view: View, ancestor: View): Boolean =
        generateSequence(view) { it.parent as? View }.any { it === ancestor }

    fun goBack(): Boolean {
        val navigator = delegate.currentNavigator ?: return false
        if (navigator.isAtStartDestination()) return leaveRoot()
        leaveScreen(forward = false)
        navigator.pop()
        return true
    }

    private val backWithTransition = object : OnBackPressedCallback(true) {
        override fun handleOnBackPressed() {
            if (!goBack()) {
                isEnabled = false
                onBackPressedDispatcher.onBackPressed()
                isEnabled = true
            }
        }
    }

    fun showNativeSignIn() {
        TopBarState.clear(this)
        SignInActivity.open(this)
        finish()
    }

    fun requestPush(grant: (String?) -> Unit) {
        pendingGrant = grant
        val needsPermission = Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED
        if (needsPermission) notificationPermission.launch(Manifest.permission.POST_NOTIFICATIONS) else fetchPushToken()
    }

    private fun fetchPushToken() {
        val token = runCatching { FirebaseMessaging.getInstance().token }.getOrNull() ?: return finishGrant(null)
        token.addOnCompleteListener { task -> finishGrant(if (task.isSuccessful) task.result else null) }
    }

    private fun finishGrant(token: String?) {
        pendingGrant?.invoke(token)
        pendingGrant = null
    }

    private fun fitScreensBetweenStatusBarAndTabs() {
        ViewCompat.setOnApplyWindowInsetsListener(findViewById(R.id.screens)) { view, insets ->
            val bars = insets.getInsets(WindowInsetsCompat.Type.systemBars() or WindowInsetsCompat.Type.displayCutout())
            view.setPadding(bars.left, bars.top, bars.right, if (tabsShown) 0 else bars.bottom)
            topBar?.applyStatusInset(bars.top)
            pullConsole?.updateLayoutParams<ViewGroup.MarginLayoutParams> {
                topMargin = bars.top + resources.getDimensionPixelSize(R.dimen.top_bar_height) + resources.getDimensionPixelSize(R.dimen.pull_console_gap)
            }
            findViewById<View>(R.id.status_backdrop).updateLayoutParams { height = bars.top }
            WindowInsetsCompat.Builder(insets)
                .setInsets(WindowInsetsCompat.Type.systemBars(), Insets.NONE)
                .setInsets(WindowInsetsCompat.Type.displayCutout(), Insets.NONE)
                .build()
        }
    }

    private companion object {
        const val SCREEN_SHOWN = "window.dispatchEvent(new CustomEvent('gameble:screen-shown'))"
        const val CAPSULES_PATH = "/booster"
    }
}
