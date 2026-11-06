package net.gameble.app.bridge

import dev.hotwire.core.bridge.BridgeComponent
import dev.hotwire.core.bridge.BridgeDelegate
import dev.hotwire.core.bridge.Message
import dev.hotwire.navigation.destinations.HotwireDestination
import kotlinx.serialization.Serializable
import net.gameble.app.GamebleActivity

class BackComponent(name: String, private val delegate: BridgeDelegate<HotwireDestination>) :
    BridgeComponent<HotwireDestination>(name, delegate) {

    override fun onReceive(message: Message) {
        when (message.event) {
            "screen" -> message.data<ScreenData>()?.let { screenLabels[delegate.destination.location] = it.label }
            "connect" -> connect()
            "back" -> host?.goBack()
        }
    }

    private val host: GamebleActivity?
        get() = delegate.destination.fragment.activity as? GamebleActivity

    private fun connect() {
        val navigator = delegate.destination.navigator
        val atRoot = navigator.isAtStartDestination()
        val previousLabel = if (atRoot) null else navigator.previousLocation?.let { screenLabels[it] }
        replyTo("connect", Reply(canGoBack = !atRoot || host?.rootHasWayBack == true, previousLabel))
    }

    @Serializable
    data class ScreenData(val label: String)

    @Serializable
    data class Reply(val canGoBack: Boolean, val previousLabel: String?)

    private companion object {
        val screenLabels = mutableMapOf<String, String>()
    }
}
