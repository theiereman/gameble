package net.gameble.app

import android.content.Intent
import android.os.Bundle
import android.view.MotionEvent
import android.view.View
import android.widget.FrameLayout
import androidx.core.view.ViewCompat
import com.google.android.material.bottomnavigation.BottomNavigationView
import dev.hotwire.navigation.tabs.HotwireBottomNavigationController
import dev.hotwire.navigation.tabs.HotwireBottomNavigationController.Visibility
import dev.hotwire.navigation.tabs.navigatorConfigurations

class MainActivity : GamebleActivity() {
    private val tabs by lazy { Tabs.all(this) }
    private lateinit var bottomNavigation: HotwireBottomNavigationController
    private val debugLog by lazy { if (BuildConfig.DEBUG) DebugLogPanel(this) else null }
    private val tabSlide = TabSlide()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (!PlayerSession.probablySignedIn(this)) return showNativeSignIn()
        setContentView(R.layout.activity_main)
        tabsShown = true
        val bottomNavigationView = findViewById<BottomNavigationView>(R.id.bottom_navigation)
        bottomNavigationView.isItemActiveIndicatorEnabled = false
        bottomNavigation = HotwireBottomNavigationController(this, bottomNavigationView, lazyLoadTabs = false)
        bottomNavigation.load(tabs)
        setUpScreens()
        bottomNavigation.setOnTabSelectedListener { index, tab ->
            dropScreenTransition()
            tabSlide.switched(findViewById(tab.configuration.navigatorHostId), index)
            delegate.currentNavigator?.let { screenOnView(it) }
            bottomNavigationView.post { announceScreenShown() }
        }
        val start = bottomNavigation.currentTab
        tabSlide.switched(findViewById(start.configuration.navigatorHostId), tabs.indexOf(start))
        debugLog?.attachTo(findViewById<FrameLayout>(R.id.screens))
        openPathFrom(intent)
    }

    override fun dispatchTouchEvent(event: MotionEvent): Boolean {
        debugLog?.onTouch(event)
        return super.dispatchTouchEvent(event)
    }

    override fun navigatorConfigurations() = tabs.navigatorConfigurations

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        openPathFrom(intent)
    }

    override fun currentScreen(): View = findViewById(bottomNavigation.currentTab.configuration.navigatorHostId)

    override fun showTabs(shown: Boolean) {
        tabsShown = shown
        bottomNavigation.visibility = if (shown) Visibility.DEFAULT else Visibility.HIDDEN
        ViewCompat.requestApplyInsets(findViewById(R.id.screens))
    }

    override fun openDestination(path: String) {
        val destination = Tabs.destination(path)
        val tab = destination.tab ?: return openAboveTabs(path)
        showTab(tab, Gameble.location(path).takeUnless { destination.atRoot })
    }

    private fun openAboveTabs(path: String) {
        LayerActivity.open(this, Gameble.location(path), TopBarState.label(delegate.currentNavigator?.location))
    }

    private fun showTab(index: Int, location: String?) {
        bottomNavigation.selectTab(index)
        bottomNavigation.view.post {
            val navigator = delegate.currentNavigator ?: return@post
            val visit = { if (location != null) navigator.route(location) }
            if (navigator.isAtStartDestination()) visit() else navigator.clearAll(visit)
        }
    }

    private fun openPathFrom(intent: Intent?) {
        intent?.getStringExtra(TOP_BAR_PATH)?.let { path ->
            intent.removeExtra(TOP_BAR_PATH)
            openDestination(path)
        }
        val path = intent?.getStringExtra(PushService.PATH_EXTRA) ?: return
        intent.removeExtra(PushService.PATH_EXTRA)
        delegate.currentNavigator?.route(Gameble.location(path))
    }

    companion object {
        const val TOP_BAR_PATH = "top_bar_path"
    }
}
