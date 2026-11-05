package net.gameble.app

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.view.MotionEvent
import android.view.View
import android.widget.FrameLayout
import androidx.activity.OnBackPressedCallback
import androidx.activity.result.contract.ActivityResultContracts
import androidx.core.content.ContextCompat
import androidx.core.graphics.Insets
import androidx.core.view.ViewCompat
import androidx.core.view.WindowInsetsCompat
import com.google.android.material.bottomnavigation.BottomNavigationView
import com.google.firebase.messaging.FirebaseMessaging
import dev.hotwire.navigation.activities.HotwireActivity
import dev.hotwire.navigation.tabs.HotwireBottomNavigationController
import dev.hotwire.navigation.tabs.HotwireBottomNavigationController.Visibility
import dev.hotwire.navigation.tabs.navigatorConfigurations

class MainActivity : HotwireActivity() {
    private val tabs by lazy { Tabs.all(this) }
    private lateinit var bottomNavigation: HotwireBottomNavigationController
    private val debugLog by lazy { if (BuildConfig.DEBUG) DebugLogPanel(this) else null }
    private var pendingGrant: ((String?) -> Unit)? = null
    private val tabSlide = TabSlide()
    private lateinit var screenTransition: ScreenTransition
    private var tabsShown = true

    private val notificationPermission = registerForActivityResult(ActivityResultContracts.RequestPermission()) { granted ->
        if (granted) fetchPushToken() else finishGrant(null)
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (!PlayerSession.probablySignedIn(this)) return showNativeSignIn()
        setContentView(R.layout.activity_main)
        fitScreensBetweenStatusBarAndTabs()
        val bottomNavigationView = findViewById<BottomNavigationView>(R.id.bottom_navigation)
        bottomNavigationView.isItemActiveIndicatorEnabled = false
        bottomNavigation = HotwireBottomNavigationController(this, bottomNavigationView, lazyLoadTabs = false)
        bottomNavigation.load(tabs)
        screenTransition = ScreenTransition(findViewById(R.id.screens))
        bottomNavigation.setOnTabSelectedListener { index, tab ->
            screenTransition.drop()
            tabSlide.switched(findViewById(tab.configuration.navigatorHostId), index)
        }
        val start = bottomNavigation.currentTab
        tabSlide.switched(findViewById(start.configuration.navigatorHostId), tabs.indexOf(start))
        debugLog?.attachTo(findViewById<FrameLayout>(R.id.screens))
        onBackPressedDispatcher.addCallback(this, backWithTransition)
        openNotificationPath(intent)
    }

    override fun dispatchTouchEvent(event: MotionEvent): Boolean {
        debugLog?.onTouch(event)
        return super.dispatchTouchEvent(event)
    }

    override fun navigatorConfigurations() = tabs.navigatorConfigurations

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        openNotificationPath(intent)
    }

    fun leaveScreen(forward: Boolean) {
        screenTransition.leave(window, currentScreen(), forward)
    }

    fun screenArrived(page: View) {
        if (page.parent != null && isInside(page, currentScreen())) screenTransition.arrived(page)
    }

    private fun currentScreen(): View = findViewById(bottomNavigation.currentTab.configuration.navigatorHostId)

    private fun isInside(view: View, ancestor: View): Boolean =
        generateSequence(view) { it.parent as? View }.any { it === ancestor }

    fun goBack(): Boolean {
        val navigator = delegate.currentNavigator ?: return false
        if (navigator.isAtStartDestination()) return false
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

    fun showTabs(shown: Boolean) {
        tabsShown = shown
        bottomNavigation.visibility = if (shown) Visibility.DEFAULT else Visibility.HIDDEN
        ViewCompat.requestApplyInsets(findViewById(R.id.screens))
    }

    fun showNativeSignIn() {
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
            WindowInsetsCompat.Builder(insets)
                .setInsets(WindowInsetsCompat.Type.systemBars(), Insets.NONE)
                .setInsets(WindowInsetsCompat.Type.displayCutout(), Insets.NONE)
                .build()
        }
    }

    private fun openNotificationPath(intent: Intent?) {
        val path = intent?.getStringExtra(PushService.PATH_EXTRA) ?: return
        intent.removeExtra(PushService.PATH_EXTRA)
        delegate.currentNavigator?.route("${Gameble.ROOT_URL}$path")
    }

}
