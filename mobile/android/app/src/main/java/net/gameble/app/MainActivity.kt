package net.gameble.app

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import androidx.activity.result.contract.ActivityResultContracts
import androidx.core.content.ContextCompat
import com.google.android.material.bottomnavigation.BottomNavigationView
import com.google.firebase.messaging.FirebaseMessaging
import dev.hotwire.navigation.activities.HotwireActivity
import dev.hotwire.navigation.tabs.HotwireBottomNavigationController
import dev.hotwire.navigation.tabs.navigatorConfigurations

class MainActivity : HotwireActivity() {
    private val tabs by lazy { Tabs.all(this) }
    private lateinit var bottomNavigation: HotwireBottomNavigationController
    private var pendingGrant: ((String?) -> Unit)? = null

    private val notificationPermission = registerForActivityResult(ActivityResultContracts.RequestPermission()) { granted ->
        if (granted) fetchPushToken() else finishGrant(null)
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)
        bottomNavigation = HotwireBottomNavigationController(this, findViewById<BottomNavigationView>(R.id.bottom_navigation))
        bottomNavigation.load(tabs)
        openNotificationPath(intent)
    }

    override fun navigatorConfigurations() = tabs.navigatorConfigurations

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        openNotificationPath(intent)
    }

    fun requestPush(grant: (String?) -> Unit) {
        pendingGrant = grant
        val needsPermission = Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED
        if (needsPermission) notificationPermission.launch(Manifest.permission.POST_NOTIFICATIONS) else fetchPushToken()
    }

    private fun fetchPushToken() {
        FirebaseMessaging.getInstance().token.addOnCompleteListener { task ->
            finishGrant(if (task.isSuccessful) task.result else null)
        }
    }

    private fun finishGrant(token: String?) {
        pendingGrant?.invoke(token)
        pendingGrant = null
    }

    private fun openNotificationPath(intent: Intent?) {
        val path = intent?.getStringExtra(PushService.PATH_EXTRA) ?: return
        intent.removeExtra(PushService.PATH_EXTRA)
        delegate.currentNavigator?.route("${Gameble.ROOT_URL}$path")
    }
}
