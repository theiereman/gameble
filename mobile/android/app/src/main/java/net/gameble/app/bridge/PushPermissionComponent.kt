package net.gameble.app.bridge

import dev.hotwire.core.bridge.BridgeComponent
import dev.hotwire.core.bridge.BridgeDelegate
import dev.hotwire.core.bridge.Message
import dev.hotwire.navigation.destinations.HotwireDestination
import kotlinx.serialization.Serializable
import net.gameble.app.MainActivity

class PushPermissionComponent(name: String, private val delegate: BridgeDelegate<HotwireDestination>) :
    BridgeComponent<HotwireDestination>(name, delegate) {

    override fun onReceive(message: Message) {
        if (message.event != "request") return
        val activity = delegate.destination.fragment.activity as? MainActivity ?: return

        activity.requestPush { token ->
            if (token != null) replyTo("request", Grant(token = token, platform = "google")) else replyTo("request", Refusal())
        }
    }

    @Serializable
    data class Grant(val token: String, val platform: String)

    @Serializable
    data class Refusal(val granted: Boolean = false)
}
