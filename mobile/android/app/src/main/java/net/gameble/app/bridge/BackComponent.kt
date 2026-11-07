package net.gameble.app.bridge

import dev.hotwire.core.bridge.BridgeComponent
import dev.hotwire.core.bridge.BridgeDelegate
import dev.hotwire.core.bridge.Message
import dev.hotwire.navigation.destinations.HotwireDestination
import kotlinx.serialization.Serializable
import net.gameble.app.GamebleActivity
import net.gameble.app.TopBarState

class BackComponent(name: String, private val delegate: BridgeDelegate<HotwireDestination>) :
    BridgeComponent<HotwireDestination>(name, delegate) {

    override fun onReceive(message: Message) {
        if (message.event != "screen") return
        val label = message.data<ScreenData>()?.label ?: return
        TopBarState.rememberLabel(delegate.destination.location, label)
        (delegate.destination.fragment.activity as? GamebleActivity)?.screenLabelsChanged()
    }

    @Serializable
    data class ScreenData(val label: String)
}
