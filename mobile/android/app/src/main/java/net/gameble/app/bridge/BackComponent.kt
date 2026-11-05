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
            "connect" -> connect(message)
            "back" -> (delegate.destination.fragment.activity as? MainActivity)?.goBack()
        }
    }

    private fun connect(message: Message) {
        val destination = delegate.destination
        message.data<ConnectData>()?.label?.let { screenLabels[destination.location] = it }
        val navigator = destination.navigator
        val canGoBack = !navigator.isAtStartDestination()
        val previousLabel = if (canGoBack) navigator.previousLocation?.let { screenLabels[it] } else null
        replyTo("connect", Reply(canGoBack, previousLabel))
    }

    @Serializable
    data class ConnectData(val label: String? = null)

    @Serializable
    data class Reply(val canGoBack: Boolean, val previousLabel: String?)

    private companion object {
        val screenLabels = mutableMapOf<String, String>()
    }
}
