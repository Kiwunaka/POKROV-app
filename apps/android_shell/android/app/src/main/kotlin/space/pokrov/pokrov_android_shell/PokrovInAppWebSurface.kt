package space.pokrov.pokrov_android_shell

import android.annotation.SuppressLint
import android.app.Activity
import android.content.Intent
import android.graphics.Color
import android.graphics.Typeface
import android.net.Uri
import android.os.Bundle
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.webkit.CookieManager
import android.webkit.SslErrorHandler
import android.webkit.WebChromeClient
import android.webkit.WebResourceRequest
import android.webkit.WebSettings
import android.webkit.WebView
import android.webkit.WebViewClient
import android.widget.ImageButton
import android.widget.LinearLayout
import android.widget.ProgressBar
import android.widget.TextView
import java.net.URI

internal enum class PokrovWebNavigationDecision {
    IN_APP,
    EXTERNAL,
    BLOCK,
}

internal object PokrovWebSurfacePolicy {
    private val inAppHosts = setOf(
        "app.pokrov.space",
        "pokrov.space",
        "www.pokrov.space",
    )

    fun initialUrlAllowed(value: String?): Boolean =
        decision(value, initial = true) == PokrovWebNavigationDecision.IN_APP

    fun decision(value: String?, initial: Boolean = false): PokrovWebNavigationDecision {
        val uri = runCatching { URI(value?.trim().orEmpty()) }.getOrNull()
            ?: return PokrovWebNavigationDecision.BLOCK
        val scheme = uri.scheme?.lowercase().orEmpty()
        val host = uri.host?.lowercase().orEmpty()
        if (scheme == "https" &&
            host in inAppHosts &&
            uri.userInfo == null &&
            (uri.port == -1 || uri.port == 443)
        ) {
            return PokrovWebNavigationDecision.IN_APP
        }
        if (!initial && scheme in setOf("https", "tg", "mailto")) {
            return PokrovWebNavigationDecision.EXTERNAL
        }
        return PokrovWebNavigationDecision.BLOCK
    }
}

internal object PokrovInAppWebSurface {
    const val EXTRA_URL = "space.pokrov.web.URL"
    const val EXTRA_TITLE = "space.pokrov.web.TITLE"

    fun open(activity: Activity, url: String?, title: String?): Boolean {
        val safeUrl = url?.trim().orEmpty()
        if (!PokrovWebSurfacePolicy.initialUrlAllowed(safeUrl)) {
            return false
        }
        return runCatching {
            activity.startActivity(
                Intent(activity, PokrovWebSurfaceActivity::class.java).apply {
                    putExtra(EXTRA_URL, safeUrl)
                    putExtra(EXTRA_TITLE, title?.trim().orEmpty().take(48))
                },
            )
            true
        }.getOrDefault(false)
    }
}

class PokrovWebSurfaceActivity : Activity() {
    private lateinit var webView: WebView
    private lateinit var progress: ProgressBar
    private var initialHistoryCleared = false

    @SuppressLint("SetJavaScriptEnabled")
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val initialUrl = intent.getStringExtra(PokrovInAppWebSurface.EXTRA_URL)
        if (!PokrovWebSurfacePolicy.initialUrlAllowed(initialUrl)) {
            finish()
            return
        }

        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setBackgroundColor(Color.rgb(247, 246, 240))
        }
        root.addView(buildToolbar(), LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            dp(58),
        ))
        progress = ProgressBar(
            this,
            null,
            android.R.attr.progressBarStyleHorizontal,
        ).apply {
            max = 100
            progress = 0
        }
        root.addView(progress, LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            dp(2),
        ))

        webView = WebView(this).apply {
            setBackgroundColor(Color.WHITE)
            settings.javaScriptEnabled = true
            settings.domStorageEnabled = true
            settings.allowFileAccess = false
            settings.allowContentAccess = false
            settings.mediaPlaybackRequiresUserGesture = true
            settings.mixedContentMode = WebSettings.MIXED_CONTENT_NEVER_ALLOW
            settings.javaScriptCanOpenWindowsAutomatically = false
            settings.setSupportMultipleWindows(false)
            settings.setGeolocationEnabled(false)
            settings.setSupportZoom(false)
            settings.userAgentString = "${settings.userAgentString} POKROV-InApp/1"
            CookieManager.getInstance().setAcceptThirdPartyCookies(this, false)
            webChromeClient = object : WebChromeClient() {
                override fun onProgressChanged(view: WebView?, newProgress: Int) {
                    this@PokrovWebSurfaceActivity.progress.progress =
                        newProgress.coerceIn(0, 100)
                    this@PokrovWebSurfaceActivity.progress.visibility =
                        if (newProgress >= 100) View.GONE else View.VISIBLE
                }
            }
            webViewClient = object : WebViewClient() {
                override fun shouldOverrideUrlLoading(
                    view: WebView?,
                    request: WebResourceRequest?,
                ): Boolean = handleNavigation(request?.url?.toString())

                @Suppress("DEPRECATION")
                override fun shouldOverrideUrlLoading(view: WebView?, url: String?): Boolean =
                    handleNavigation(url)

                override fun onPageFinished(view: WebView?, url: String?) {
                    super.onPageFinished(view, url)
                    if (!initialHistoryCleared) {
                        view?.clearHistory()
                        initialHistoryCleared = true
                    }
                }

                override fun onReceivedSslError(
                    view: WebView?,
                    handler: SslErrorHandler?,
                    error: android.net.http.SslError?,
                ) {
                    handler?.cancel()
                }
            }
            setDownloadListener { url, _, _, _, _ -> openExternal(url) }
        }
        root.addView(webView, LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            0,
            1f,
        ))
        setContentView(root)
        initialHistoryCleared = savedInstanceState?.getBoolean(
            STATE_INITIAL_HISTORY_CLEARED,
            false,
        ) ?: false
        val restored = savedInstanceState != null && webView.restoreState(savedInstanceState) != null
        if (!restored) {
            webView.loadUrl(initialUrl.orEmpty())
        }
    }

    private fun buildToolbar(): View {
        val toolbar = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding(dp(6), 0, dp(6), 0)
            setBackgroundColor(Color.rgb(247, 246, 240))
        }
        toolbar.addView(toolbarButton(
            icon = android.R.drawable.ic_media_previous,
            description = "Назад",
        ) { navigateBack() })
        val labels = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding(dp(8), 0, dp(4), 0)
        }
        labels.addView(TextView(this).apply {
            text = intent.getStringExtra(PokrovInAppWebSurface.EXTRA_TITLE)
                ?.takeIf { it.isNotBlank() }
                ?: "POKROV"
            setTextColor(Color.rgb(21, 36, 31))
            textSize = 16f
            typeface = Typeface.DEFAULT_BOLD
            maxLines = 1
        })
        labels.addView(TextView(this).apply {
            text = runCatching {
                URI(intent.getStringExtra(PokrovInAppWebSurface.EXTRA_URL).orEmpty()).host
            }.getOrNull().orEmpty().ifBlank { "pokrov.space" }
            setTextColor(Color.rgb(91, 105, 99))
            textSize = 12f
            maxLines = 1
        })
        toolbar.addView(labels, LinearLayout.LayoutParams(0, dp(58), 1f))
        toolbar.addView(toolbarButton(
            icon = android.R.drawable.ic_menu_close_clear_cancel,
            description = "Закрыть",
        ) { finish() })
        return toolbar
    }

    private fun toolbarButton(
        icon: Int,
        description: String,
        action: () -> Unit,
    ): ImageButton = ImageButton(this).apply {
        setImageResource(icon)
        contentDescription = description
        setBackgroundColor(Color.TRANSPARENT)
        setColorFilter(Color.rgb(21, 36, 31))
        setOnClickListener { action() }
        layoutParams = LinearLayout.LayoutParams(dp(48), dp(48))
    }

    private fun handleNavigation(value: String?): Boolean = when (
        PokrovWebSurfacePolicy.decision(value)
    ) {
        PokrovWebNavigationDecision.IN_APP -> false
        PokrovWebNavigationDecision.EXTERNAL -> {
            openExternal(value)
            true
        }
        PokrovWebNavigationDecision.BLOCK -> true
    }

    private fun openExternal(value: String?) {
        val raw = value?.trim().orEmpty()
        if (PokrovWebSurfacePolicy.decision(raw) != PokrovWebNavigationDecision.EXTERNAL) {
            return
        }
        runCatching {
            startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(raw)))
        }
    }

    private fun navigateBack() {
        if (::webView.isInitialized && webView.canGoBack()) {
            webView.goBack()
        } else {
            finish()
        }
    }

    @Deprecated("Android still dispatches the legacy callback on supported direct-APK devices.")
    override fun onBackPressed() {
        navigateBack()
    }

    override fun onDestroy() {
        if (::webView.isInitialized) {
            webView.stopLoading()
            webView.webChromeClient = null
            webView.webViewClient = WebViewClient()
            webView.removeAllViews()
            webView.destroy()
        }
        super.onDestroy()
    }

    override fun onSaveInstanceState(outState: Bundle) {
        if (::webView.isInitialized) {
            webView.saveState(outState)
        }
        outState.putBoolean(STATE_INITIAL_HISTORY_CLEARED, initialHistoryCleared)
        super.onSaveInstanceState(outState)
    }

    private fun dp(value: Int): Int =
        (value * resources.displayMetrics.density).toInt()

    private companion object {
        const val STATE_INITIAL_HISTORY_CLEARED = "pokrov.web.initial_history_cleared"
    }
}
