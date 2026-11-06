package net.gameble.app

import android.app.Activity
import android.content.Intent
import android.os.Bundle
import android.view.View
import dev.hotwire.navigation.navigator.NavigatorConfiguration

class LayerActivity : GamebleActivity() {
    override val rootBackLabel: String
        get() = intent.getStringExtra(PREVIOUS_LABEL) ?: getString(R.string.top_bar_back)

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_layer)
        setUpScreens()
    }

    override fun navigatorConfigurations() = listOf(
        NavigatorConfiguration(
            name = "layer",
            startLocation = requireNotNull(intent.getStringExtra(LOCATION)),
            navigatorHostId = R.id.layer_host
        )
    )

    override fun currentScreen(): View = findViewById(R.id.layer_host)

    override fun leaveRoot(): Boolean {
        finish()
        return true
    }

    override fun finish() {
        super.finish()
        overridePendingTransition(0, 0)
    }

    override fun openDestination(path: String) {
        if (Tabs.destination(path).tab == null) {
            delegate.currentNavigator?.route(Gameble.location(path))
        } else {
            startActivity(Intent(this, MainActivity::class.java).putExtra(MainActivity.TOP_BAR_PATH, path))
            overridePendingTransition(0, 0)
        }
    }

    companion object {
        private const val LOCATION = "location"
        private const val PREVIOUS_LABEL = "previous_label"

        fun open(activity: Activity, location: String, previousLabel: String?) {
            activity.startActivity(
                Intent(activity, LayerActivity::class.java)
                    .putExtra(LOCATION, location)
                    .putExtra(PREVIOUS_LABEL, previousLabel)
            )
            activity.overridePendingTransition(0, 0)
        }
    }
}
