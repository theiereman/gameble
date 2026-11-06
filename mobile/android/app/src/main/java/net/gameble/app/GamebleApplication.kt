package net.gameble.app

import android.app.Application
import dev.hotwire.core.bridge.BridgeComponentFactory
import dev.hotwire.core.bridge.KotlinXJsonConverter
import dev.hotwire.core.config.Hotwire
import dev.hotwire.core.logging.HotwireLogLevel
import dev.hotwire.core.turbo.config.PathConfiguration
import dev.hotwire.navigation.config.defaultFragmentDestination
import dev.hotwire.navigation.config.registerBridgeComponents
import dev.hotwire.navigation.config.registerFragmentDestinations
import net.gameble.app.bridge.BackComponent
import net.gameble.app.bridge.HapticsComponent
import net.gameble.app.bridge.PushPermissionComponent
import net.gameble.app.bridge.ShareComponent
import net.gameble.app.bridge.SheetComponent
import net.gameble.app.bridge.TopBarComponent
import net.gameble.app.bridge.SignInComponent

class GamebleApplication : Application() {
    override fun onCreate() {
        super.onCreate()

        if (BuildConfig.DEBUG) {
            Hotwire.config.logger.logLevel = HotwireLogLevel.DEBUG
            Hotwire.config.webViewDebuggingEnabled = true
        }
        Hotwire.config.applicationUserAgentPrefix = "Gameble Android;"
        Hotwire.config.jsonConverter = KotlinXJsonConverter()
        Hotwire.loadPathConfiguration(
            context = this,
            location = PathConfiguration.Location(
                assetFilePath = "json/path-configuration.json",
                remoteFileUrl = "${Gameble.ROOT_URL}/configurations/android_v1.json"
            )
        )
        Hotwire.defaultFragmentDestination = GamebleWebFragment::class
        Hotwire.registerFragmentDestinations(GamebleWebFragment::class, GamebleSheetFragment::class)
        Hotwire.registerBridgeComponents(
            BridgeComponentFactory("back", ::BackComponent),
            BridgeComponentFactory("sign-in", ::SignInComponent),
            BridgeComponentFactory("push-permission", ::PushPermissionComponent),
            BridgeComponentFactory("share", ::ShareComponent),
            BridgeComponentFactory("haptics", ::HapticsComponent),
            BridgeComponentFactory("sheet", ::SheetComponent),
            BridgeComponentFactory("top-bar", ::TopBarComponent)
        )
        PushService.createChannel(this)
    }
}
