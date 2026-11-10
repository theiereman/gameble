package net.gameble.app.bridge

import dev.hotwire.core.bridge.BridgeComponent
import dev.hotwire.core.bridge.BridgeDelegate
import dev.hotwire.core.bridge.Message
import dev.hotwire.navigation.destinations.HotwireDestination
import net.gameble.app.GamebleWebFragment

class PullToRefreshComponent(name: String, private val delegate: BridgeDelegate<HotwireDestination>) :
    BridgeComponent<HotwireDestination>(name, delegate) {

    override fun onReceive(message: Message) {
        val screen = delegate.destination.fragment as? GamebleWebFragment ?: return
        when (message.event) {
            "hold" -> screen.pullHeld = true
            "release" -> screen.pullHeld = false
        }
    }
}
