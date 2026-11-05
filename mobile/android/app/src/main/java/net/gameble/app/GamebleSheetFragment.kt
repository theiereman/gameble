package net.gameble.app

import android.os.Bundle
import android.view.View
import dev.hotwire.navigation.destinations.HotwireDestinationDeepLink
import dev.hotwire.navigation.fragments.HotwireWebBottomSheetFragment

@HotwireDestinationDeepLink(uri = "hotwire://fragment/gameble/sheet")
class GamebleSheetFragment : HotwireWebBottomSheetFragment() {
    override fun getTheme() = R.style.ThemeOverlay_Gameble_Sheet

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)
        hideAppBar()
    }
}
