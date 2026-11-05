package net.gameble.app

import android.content.Context
import android.webkit.CookieManager

object PlayerSession {
    private const val PREFERENCES = "player_session"
    private const val SIGNED_IN = "signed_in"
    private const val SESSION_COOKIE = "_gameble_session="

    fun probablySignedIn(context: Context): Boolean =
        preferences(context).getBoolean(SIGNED_IN, holdsSessionCookie())

    fun signedIn(context: Context) = preferences(context).edit().putBoolean(SIGNED_IN, true).apply()

    fun signedOut(context: Context) = preferences(context).edit().putBoolean(SIGNED_IN, false).apply()

    private fun holdsSessionCookie(): Boolean =
        CookieManager.getInstance().getCookie(Gameble.ROOT_URL)?.contains(SESSION_COOKIE) == true

    private fun preferences(context: Context) = context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE)
}
