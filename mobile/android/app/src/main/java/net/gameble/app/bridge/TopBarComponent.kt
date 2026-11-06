package net.gameble.app.bridge

import dev.hotwire.core.bridge.BridgeComponent
import dev.hotwire.core.bridge.BridgeDelegate
import dev.hotwire.core.bridge.Message
import dev.hotwire.navigation.destinations.HotwireDestination
import kotlinx.serialization.Serializable
import net.gameble.app.GamebleActivity
import net.gameble.app.GamebleWebFragment
import net.gameble.app.TopBarReport

class TopBarComponent(name: String, private val delegate: BridgeDelegate<HotwireDestination>) :
    BridgeComponent<HotwireDestination>(name, delegate) {

    private val host: GamebleActivity?
        get() = delegate.destination.fragment.activity as? GamebleActivity

    override fun onReceive(message: Message) {
        when (message.event) {
            "navigate" -> message.data<Destination>()?.let { host?.openDestination(it.path) }
            "state" -> message.data<TopBarReport>()?.let { host?.topBarReported(delegate.destination.navigator, it) }
            "dialog" -> message.data<DialogState>()?.let { (delegate.destination.fragment as? GamebleWebFragment)?.dialogChanged(it.open) }
        }
    }

    @Serializable
    data class Destination(val path: String)

    @Serializable
    data class DialogState(val open: Boolean)
}
