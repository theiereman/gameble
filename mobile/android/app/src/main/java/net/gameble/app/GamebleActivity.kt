package net.gameble.app

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import android.view.View
import androidx.activity.OnBackPressedCallback
import androidx.activity.result.contract.ActivityResultContracts
import androidx.core.content.ContextCompat
import androidx.core.graphics.Insets
import androidx.core.view.ViewCompat
import androidx.core.view.WindowInsetsCompat
import com.google.firebase.messaging.FirebaseMessaging
import dev.hotwire.navigation.activities.HotwireActivity

abstract class GamebleActivity : HotwireActivity() {
    private var pendingGrant: ((String?) -> Unit)? = null
    private lateinit var screenTransition: ScreenTransition
    protected var tabsShown = false

    private val notificationPermission = registerForActivityResult(ActivityResultContracts.RequestPermission()) { granted ->
        if (granted) fetchPushToken() else finishGrant(null)
    }

    open val rootHasWayBack: Boolean get() = false

    abstract fun openFromTopBar(path: String)

    protected abstract fun currentScreen(): View

    protected open fun leaveRoot(): Boolean = false

    open fun showTabs(shown: Boolean) = Unit

    protected fun setUpScreens() {
        fitScreensBetweenStatusBarAndTabs()
        screenTransition = ScreenTransition(findViewById(R.id.screens))
        onBackPressedDispatcher.addCallback(this, backWithTransition)
    }

    override fun onRestart() {
        super.onRestart()
        announceScreenShown()
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

    private companion object {
        const val SCREEN_SHOWN = "window.dispatchEvent(new CustomEvent('gameble:screen-shown'))"
    }
}
