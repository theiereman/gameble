package net.gameble.app.bridge

import android.content.Intent
import dev.hotwire.core.bridge.BridgeComponent
import dev.hotwire.core.bridge.BridgeDelegate
import dev.hotwire.core.bridge.Message
import dev.hotwire.navigation.destinations.HotwireDestination
import kotlinx.serialization.Serializable

class ShareComponent(name: String, private val delegate: BridgeDelegate<HotwireDestination>) :
    BridgeComponent<HotwireDestination>(name, delegate) {

    override fun onReceive(message: Message) {
        if (message.event != "share") return
        val data = message.data<MessageData>() ?: return

        val send = Intent(Intent.ACTION_SEND).setType("text/plain").putExtra(Intent.EXTRA_TEXT, "${data.text} ${data.url}")
        delegate.destination.fragment.startActivity(Intent.createChooser(send, null))
    }

    @Serializable
    data class MessageData(val url: String, val text: String)
}
