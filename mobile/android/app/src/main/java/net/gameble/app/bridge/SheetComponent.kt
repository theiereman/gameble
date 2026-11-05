package net.gameble.app.bridge

import androidx.fragment.app.DialogFragment
import dev.hotwire.core.bridge.BridgeComponent
import dev.hotwire.core.bridge.BridgeDelegate
import dev.hotwire.core.bridge.Message
import dev.hotwire.navigation.destinations.HotwireDestination
import net.gameble.app.MainActivity

class SheetComponent(name: String, private val delegate: BridgeDelegate<HotwireDestination>) :
    BridgeComponent<HotwireDestination>(name, delegate) {

    override fun onReceive(message: Message) {
        val fragment = delegate.destination.fragment
        when (message.event) {
            "shown" -> (fragment.activity as? MainActivity)?.showTabs(false)
            "hidden" -> (fragment.activity as? MainActivity)?.showTabs(true)
            "close" -> (fragment as? DialogFragment)?.dismiss()
        }
    }
}
