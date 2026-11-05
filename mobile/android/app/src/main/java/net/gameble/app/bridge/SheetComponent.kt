package net.gameble.app.bridge

import dev.hotwire.core.bridge.BridgeComponent
import dev.hotwire.core.bridge.BridgeDelegate
import dev.hotwire.core.bridge.Message
import dev.hotwire.navigation.destinations.HotwireDestination
import net.gameble.app.MainActivity

class SheetComponent(name: String, private val delegate: BridgeDelegate<HotwireDestination>) :
    BridgeComponent<HotwireDestination>(name, delegate) {

    override fun onReceive(message: Message) {
        val activity = delegate.destination.fragment.activity as? MainActivity ?: return
        when (message.event) {
            "shown" -> activity.showTabs(false)
            "hidden" -> activity.showTabs(true)
        }
    }
}
