package net.gameble.app.bridge

import dev.hotwire.core.bridge.BridgeComponent
import dev.hotwire.core.bridge.BridgeDelegate
import dev.hotwire.core.bridge.Message
import dev.hotwire.navigation.destinations.HotwireDestination
import dev.hotwire.navigation.destinations.HotwireDialogDestination
import net.gameble.app.GamebleActivity

class SheetComponent(name: String, private val delegate: BridgeDelegate<HotwireDestination>) :
    BridgeComponent<HotwireDestination>(name, delegate) {

    override fun onReceive(message: Message) {
        val fragment = delegate.destination.fragment
        when (message.event) {
            "shown" -> (fragment.activity as? GamebleActivity)?.showTabs(false)
            "hidden" -> (fragment.activity as? GamebleActivity)?.showTabs(true)
            "close" -> (delegate.destination as? HotwireDialogDestination)?.closeDialog()
        }
    }
}
