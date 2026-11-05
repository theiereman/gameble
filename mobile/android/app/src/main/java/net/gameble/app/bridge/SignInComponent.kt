package net.gameble.app.bridge

import dev.hotwire.core.bridge.BridgeComponent
import dev.hotwire.core.bridge.BridgeDelegate
import dev.hotwire.core.bridge.Message
import dev.hotwire.navigation.destinations.HotwireDestination
import net.gameble.app.MainActivity
import net.gameble.app.SignIn

class SignInComponent(name: String, private val delegate: BridgeDelegate<HotwireDestination>) :
    BridgeComponent<HotwireDestination>(name, delegate) {

    override fun onReceive(message: Message) {
        val fragment = delegate.destination.fragment
        when (message.event) {
            "shown" -> (fragment.activity as? MainActivity)?.showNativeSignIn()
            "start" -> SignIn.start(fragment.requireContext())
        }
    }
}
