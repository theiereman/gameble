package net.gameble.app

import android.app.Activity
import android.content.pm.ActivityInfo
import android.graphics.Color
import androidx.activity.ComponentActivity
import androidx.activity.SystemBarStyle
import androidx.activity.enableEdgeToEdge

private const val LARGE_SCREEN_MIN_WIDTH_DP = 600

fun ComponentActivity.drawBehindDarkSystemBars() {
    val transparentWithLightIcons = SystemBarStyle.dark(Color.TRANSPARENT)
    enableEdgeToEdge(statusBarStyle = transparentWithLightIcons, navigationBarStyle = transparentWithLightIcons)
}

fun Activity.keepPortraitOnPhones() {
    val phone = resources.configuration.smallestScreenWidthDp < LARGE_SCREEN_MIN_WIDTH_DP
    requestedOrientation = if (phone) ActivityInfo.SCREEN_ORIENTATION_PORTRAIT else ActivityInfo.SCREEN_ORIENTATION_UNSPECIFIED
}
