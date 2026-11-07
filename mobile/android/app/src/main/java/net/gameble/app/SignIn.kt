package net.gameble.app

import android.content.Context
import android.net.Uri
import android.util.Base64
import android.webkit.CookieManager
import androidx.browser.customtabs.CustomTabsIntent
import java.net.HttpURLConnection
import java.net.URL
import java.net.URLEncoder
import java.security.SecureRandom

// Google refuses OAuth inside a web view, so the sign-in runs in a Custom Tab and hands a ticket back.
object SignIn {
    private const val PREFERENCES = "sign_in"
    private const val STATE = "state"

    fun start(context: Context) {
        val state = randomState()
        context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE).edit().putString(STATE, state).apply()
        CustomTabsIntent.Builder().build().launchUrl(context, Uri.parse(Gameble.url("/native/sign-in/$state")))
    }

    fun takeState(context: Context): String? {
        val preferences = context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE)
        return preferences.getString(STATE, null).also { preferences.edit().remove(STATE).apply() }
    }

    fun redeem(ticket: String, state: String): Boolean {
        val url = Gameble.url("/native/session")
        val connection = URL(url).openConnection() as HttpURLConnection
        return try {
            connection.requestMethod = "POST"
            connection.instanceFollowRedirects = false
            connection.doOutput = true
            connection.setRequestProperty("User-Agent", Gameble.USER_AGENT)
            connection.setRequestProperty("Content-Type", "application/x-www-form-urlencoded")
            connection.outputStream.use { it.write(form("ticket" to ticket, "state" to state).toByteArray()) }
            if (connection.responseCode != HttpURLConnection.HTTP_NO_CONTENT) return false

            val cookies = CookieManager.getInstance()
            connection.headerFields["Set-Cookie"].orEmpty().forEach { cookies.setCookie(Gameble.ROOT_URL, it) }
            cookies.flush()
            true
        } finally {
            connection.disconnect()
        }
    }

    private fun randomState(): String {
        val bytes = ByteArray(32).also { SecureRandom().nextBytes(it) }
        return Base64.encodeToString(bytes, Base64.URL_SAFE or Base64.NO_PADDING or Base64.NO_WRAP)
    }

    private fun form(vararg fields: Pair<String, String>) =
        fields.joinToString("&") { (name, value) -> "$name=${URLEncoder.encode(value, "UTF-8")}" }
}
