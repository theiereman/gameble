package net.gameble.app

import android.app.Activity
import android.content.Intent
import android.os.Bundle
import kotlin.concurrent.thread

class SignInCallbackActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val ticket = intent.data?.getQueryParameter("ticket")
        val state = SignIn.takeState(this)
        if (ticket == null || state == null) return finish()

        thread {
            val signedIn = runCatching { SignIn.redeem(ticket, state) }.getOrDefault(false)
            runOnUiThread {
                if (signedIn) {
                    startActivity(Intent(this, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK))
                }
                finish()
            }
        }
    }
}
