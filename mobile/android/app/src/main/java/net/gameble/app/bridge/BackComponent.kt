package net.gameble.app.bridge

import dev.hotwire.core.bridge.BridgeComponent
import dev.hotwire.core.bridge.BridgeDelegate
import dev.hotwire.core.bridge.Message
import dev.hotwire.navigation.destinations.HotwireDestination
import kotlinx.serialization.Serializable
import net.gameble.app.MainActivity

class BackComponent(name: String, private val delegate: BridgeDelegate<HotwireDestination>) :
    BridgeComponent<HotwireDestination>(name, delegate) {

    override fun onReceive(message: Message) {
        when (message.event) {
            "connect" -> replyTo("connect", Reply(canGoBack = !delegate.destination.navigator.isAtStartDestination()))
            "back" -> (delegate.destination.fragment.activity as? MainActivity)?.goBack()
        }
    }

    @Serializable
    data class Reply(val canGoBack: Boolean)
}
