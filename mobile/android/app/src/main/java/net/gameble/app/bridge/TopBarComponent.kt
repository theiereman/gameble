package net.gameble.app.bridge

import dev.hotwire.core.bridge.BridgeComponent
import dev.hotwire.core.bridge.BridgeDelegate
import dev.hotwire.core.bridge.Message
import dev.hotwire.navigation.destinations.HotwireDestination
import kotlinx.serialization.Serializable
import net.gameble.app.GamebleActivity

class TopBarComponent(name: String, private val delegate: BridgeDelegate<HotwireDestination>) :
    BridgeComponent<HotwireDestination>(name, delegate) {

    override fun onReceive(message: Message) {
        if (message.event != "navigate") return
        val path = message.data<Destination>()?.path ?: return
        (delegate.destination.fragment.activity as? GamebleActivity)?.openFromTopBar(path)
    }

    @Serializable
    data class Destination(val path: String)
}
