package net.gameble.app

import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.view.View
import dev.hotwire.navigation.navigator.NavigatorConfiguration

class LayerActivity : GamebleActivity() {
    override val rootHasWayBack: Boolean get() = true

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

    override fun openFromTopBar(path: String) {
        if (Tabs.destination(path).tab == null) {
            delegate.currentNavigator?.route(Gameble.location(path))
        } else {
            startActivity(Intent(this, MainActivity::class.java).putExtra(MainActivity.TOP_BAR_PATH, path))
        }
    }

    companion object {
        private const val LOCATION = "location"

        fun open(context: Context, location: String) {
            context.startActivity(Intent(context, LayerActivity::class.java).putExtra(LOCATION, location))
        }
    }
}
