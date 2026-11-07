package net.gameble.app.bridge

import android.view.HapticFeedbackConstants
import dev.hotwire.core.bridge.BridgeComponent
import dev.hotwire.core.bridge.BridgeDelegate
import dev.hotwire.core.bridge.Message
import dev.hotwire.navigation.destinations.HotwireDestination
import kotlinx.serialization.Serializable

class HapticsComponent(name: String, private val delegate: BridgeDelegate<HotwireDestination>) :
    BridgeComponent<HotwireDestination>(name, delegate) {

    override fun onReceive(message: Message) {
        if (message.event != "impact") return
        val data = message.data<MessageData>() ?: return

        val feedback = when (data.style) {
            "heavy" -> HapticFeedbackConstants.LONG_PRESS
            "medium" -> HapticFeedbackConstants.CONTEXT_CLICK
            else -> HapticFeedbackConstants.CLOCK_TICK
        }
        delegate.destination.fragment.view?.performHapticFeedback(feedback)
    }

    @Serializable
    data class MessageData(val style: String)
}
