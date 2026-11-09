package net.gameble.app.bridge

import android.view.View
import dev.hotwire.core.bridge.BridgeComponent
import dev.hotwire.core.bridge.BridgeDelegate
import dev.hotwire.core.bridge.Message
import dev.hotwire.core.turbo.config.pullToRefreshEnabled
import dev.hotwire.navigation.destinations.HotwireDestination
import dev.hotwire.navigation.R as HotwireR

class PullToRefreshComponent(name: String, private val delegate: BridgeDelegate<HotwireDestination>) :
    BridgeComponent<HotwireDestination>(name, delegate) {

    override fun onReceive(message: Message) {
        val destination = delegate.destination
        val refresh = destination.fragment.view?.findViewById<View>(HotwireR.id.hotwire_webView_container) ?: return
        when (message.event) {
            "hold" -> refresh.isEnabled = false
            "release" -> refresh.isEnabled = destination.pathProperties.pullToRefreshEnabled
        }
    }
}
