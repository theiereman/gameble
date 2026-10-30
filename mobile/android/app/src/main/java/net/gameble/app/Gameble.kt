package net.gameble.app

import java.util.Locale

object Gameble {
    const val ROOT_URL = BuildConfig.ROOT_URL
    const val USER_AGENT = "Gameble Android; Hotwire Native Android; Turbo Native Android"

    val locale: String
        get() = if (Locale.getDefault().language == "fr") "fr" else "en"

    fun url(path: String = ""): String = "$ROOT_URL/$locale$path"
}
