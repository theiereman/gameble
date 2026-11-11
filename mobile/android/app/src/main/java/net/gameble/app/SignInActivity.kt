package net.gameble.app

import android.content.Context
import android.content.Intent
import android.content.res.Configuration
import android.os.Bundle
import android.text.Html
import android.text.method.LinkMovementMethod
import android.view.View
import android.widget.TextView
import androidx.activity.ComponentActivity
import androidx.core.view.ViewCompat
import androidx.core.view.WindowInsetsCompat

class SignInActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        drawBehindDarkSystemBars()
        keepPortraitOnPhones()
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_sign_in)
        keepClearOfSystemBars(findViewById(R.id.sign_in))
        findViewById<View>(R.id.sign_in_button).setOnClickListener { SignIn.start(this) }
        showAcceptance(findViewById(R.id.sign_in_acceptance))
    }

    override fun onConfigurationChanged(newConfig: Configuration) {
        super.onConfigurationChanged(newConfig)
        keepPortraitOnPhones()
    }

    private fun showAcceptance(view: TextView) {
        val text = getString(R.string.sign_in_acceptance, Gameble.url("/legal#legal-terms"), Gameble.url("/legal#legal-privacy"))
        view.text = Html.fromHtml(text, Html.FROM_HTML_MODE_COMPACT)
        view.movementMethod = LinkMovementMethod.getInstance()
    }

    private fun keepClearOfSystemBars(root: View) {
        val horizontal = root.paddingLeft
        ViewCompat.setOnApplyWindowInsetsListener(root) { view, insets ->
            val bars = insets.getInsets(WindowInsetsCompat.Type.systemBars() or WindowInsetsCompat.Type.displayCutout())
            view.setPadding(horizontal + bars.left, bars.top, horizontal + bars.right, bars.bottom)
            WindowInsetsCompat.CONSUMED
        }
    }

    companion object {
        fun open(context: Context) {
            PlayerSession.signedOut(context)
            context.startActivity(
                Intent(context, SignInActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK)
            )
        }
    }
}
