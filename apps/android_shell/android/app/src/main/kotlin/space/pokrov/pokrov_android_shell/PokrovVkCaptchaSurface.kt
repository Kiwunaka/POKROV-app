package space.pokrov.pokrov_android_shell

import android.annotation.SuppressLint
import android.app.Activity
import android.app.Dialog
import android.graphics.Color
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.view.ViewGroup
import android.webkit.ConsoleMessage
import android.webkit.JavascriptInterface
import android.webkit.RenderProcessGoneDetail
import android.webkit.SslErrorHandler
import android.webkit.WebChromeClient
import android.webkit.WebResourceError
import android.webkit.WebResourceRequest
import android.webkit.WebResourceResponse
import android.webkit.WebSettings
import android.webkit.WebView
import android.webkit.WebViewClient
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.LifecycleOwner
import org.json.JSONObject
import space.pokrov.core.libbox.VkCaptchaHandler
import java.io.ByteArrayInputStream
import java.lang.ref.WeakReference
import java.util.Locale
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.atomic.AtomicBoolean

/** Keeps a foreground Activity weakly and cancels pending UI when Core stops. */
internal object PokrovVkCaptchaHost {
    private val main = Handler(Looper.getMainLooper())
    private var activity = WeakReference<MainActivity>(null)

    fun attach(host: MainActivity) { activity = WeakReference(host) }
    fun detach(host: MainActivity) {
        if (activity.get() === host) activity.clear()
    }

    fun handler(submit: (String, String) -> Unit): VkCaptchaHandler = object : VkCaptchaHandler {
        private val pending = ConcurrentHashMap<String, AtomicBoolean>()

        override fun showVkCaptcha(requestId: String, challengeUrl: String) {
            val cancelled = AtomicBoolean(false)
            pending[requestId] = cancelled
            main.post {
                if (cancelled.get()) return@post
                val host = activity.get()
                if (host == null) {
                    if (pending.remove(requestId, cancelled) && !cancelled.getAndSet(true)) submit(requestId, "")
                } else {
                    host.showVkCaptcha(requestId, challengeUrl) { token ->
                        if (pending.remove(requestId, cancelled) && !cancelled.getAndSet(true)) submit(requestId, token)
                    }
                }
            }
        }

        override fun cancelVkCaptcha(requestId: String) {
            val cancelled = pending.remove(requestId) ?: return
            cancelled.set(true)
            main.post { activity.get()?.cancelVkCaptcha(requestId) }
        }
    }
}

/** One foreground VK SDK challenge. An empty result means cancellation or failure. */
internal class PokrovVkCaptchaSurface(private val activity: Activity) : AutoCloseable {
    private class Request(
        val id: String,
        var onResult: ((String) -> Unit)?,
        var dialog: Dialog? = null,
        var webView: WebView? = null,
    )

    private val lock = Any()
    private val main = Handler(Looper.getMainLooper())
    private val lifecycle = (activity as? LifecycleOwner)?.lifecycle
    private var current: Request? = null
    private var closed = false
    private val lifecycleObserver = LifecycleEventObserver { _, event ->
        when (event) {
            Lifecycle.Event.ON_PAUSE -> cancelCurrent()
            Lifecycle.Event.ON_DESTROY -> close()
            else -> Unit
        }
    }

    init {
        onMain {
            if (!synchronized(lock) { closed }) lifecycle?.addObserver(lifecycleObserver)
        }
    }

    fun show(requestId: String, challengeUrl: String, onResult: (String) -> Unit) {
        val request = synchronized(lock) {
            if (closed || current != null || requestId.isBlank()) null
            else Request(requestId, onResult).also { current = it }
        }
        if (request == null) {
            onMain { runCatching { onResult("") } }
            return
        }
        onMain { present(request, challengeUrl) }
    }

    fun cancel(requestId: String) {
        val request = synchronized(lock) {
            current?.takeIf { it.id == requestId }?.also { current = null }
        } ?: return
        deliver(request, "")
    }

    override fun close() {
        val request = synchronized(lock) {
            if (closed) return
            closed = true
            current.also { current = null }
        }
        request?.let { deliver(it, "") }
        onMain { lifecycle?.removeObserver(lifecycleObserver) }
    }

    private fun cancelCurrent() {
        val request = synchronized(lock) { current?.also { current = null } } ?: return
        deliver(request, "")
    }

    @SuppressLint("SetJavaScriptEnabled")
    private fun present(request: Request, challengeUrl: String) {
        if (!isCurrent(request)) return
        val target = sdkTarget(challengeUrl)
        if (target == null || activity.isFinishing || activity.isDestroyed || !activity.hasWindowFocus() ||
            (lifecycle != null && !lifecycle.currentState.isAtLeast(Lifecycle.State.RESUMED))) {
            finish(request, "")
            return
        }
        try {
            val view = WebView(activity)
            request.webView = view
            view.isSaveEnabled = false
            view.isSaveFromParentEnabled = false
            view.settings.apply {
                javaScriptEnabled = true
                domStorageEnabled = true
                allowFileAccess = false
                allowContentAccess = false
                @Suppress("DEPRECATION")
                allowFileAccessFromFileURLs = false
                @Suppress("DEPRECATION")
                allowUniversalAccessFromFileURLs = false
                mixedContentMode = WebSettings.MIXED_CONTENT_NEVER_ALLOW
                javaScriptCanOpenWindowsAutomatically = false
                setSupportMultipleWindows(false)
                cacheMode = WebSettings.LOAD_NO_CACHE
            }
            view.addJavascriptInterface(ResultBridge { result -> finish(request, result) }, "AndroidBridge")
            view.webChromeClient = object : WebChromeClient() {
                override fun onConsoleMessage(message: ConsoleMessage?): Boolean = true
            }
            view.webViewClient = object : WebViewClient() {
                override fun shouldOverrideUrlLoading(view: WebView?, requestInfo: WebResourceRequest?): Boolean {
                    if (allowedVk(requestInfo?.url)) return false
                    if (requestInfo?.isForMainFrame == true) finish(request, "")
                    return true
                }

                @Suppress("DEPRECATION")
                override fun shouldOverrideUrlLoading(view: WebView?, url: String?): Boolean {
                    if (allowedVk(url?.let(Uri::parse))) return false
                    finish(request, "")
                    return true
                }

                override fun shouldInterceptRequest(view: WebView?, requestInfo: WebResourceRequest?): WebResourceResponse? =
                    if (allowedVk(requestInfo?.url)) null else blocked()

                @Suppress("DEPRECATION")
                override fun shouldInterceptRequest(view: WebView?, url: String?): WebResourceResponse? =
                    if (allowedVk(url?.let(Uri::parse))) null else blocked()

                override fun onReceivedError(view: WebView?, requestInfo: WebResourceRequest?, error: WebResourceError?) {
                    if (requestInfo?.isForMainFrame == true) finish(request, "")
                }

                override fun onReceivedHttpError(
                    view: WebView?, requestInfo: WebResourceRequest?, response: WebResourceResponse?,
                ) {
                    if (requestInfo?.isForMainFrame == true && (response?.statusCode ?: 0) >= 400) finish(request, "")
                }

                override fun onReceivedSslError(
                    view: WebView?, handler: SslErrorHandler?, error: android.net.http.SslError?,
                ) {
                    handler?.cancel()
                    finish(request, "")
                }

                override fun onRenderProcessGone(view: WebView?, detail: RenderProcessGoneDetail?): Boolean {
                    finish(request, "")
                    return true
                }
            }

            val layout = LinearLayout(activity).apply { orientation = LinearLayout.VERTICAL }
            layout.addView(TextView(activity).apply {
                text = "Проверяем подключение…"
                setTextColor(Color.BLACK)
                setPadding(24, 24, 24, 24)
            })
            layout.addView(view, LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, 0, 1f,
            ))
            layout.addView(Button(activity).apply {
                text = "Отмена"
                setOnClickListener { finish(request, "") }
            })
            val dialog = Dialog(activity).apply {
                setContentView(layout)
                setCanceledOnTouchOutside(false)
                setOnCancelListener { finish(request, "") }
                setOnDismissListener { finish(request, "") }
            }
            request.dialog = dialog
            if (!isCurrent(request)) return
            dialog.show()
            dialog.window?.setLayout(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT)
            view.loadUrl(target)
        } catch (_: Throwable) {
            finish(request, "")
        }
    }

    class ResultBridge(private val result: (String) -> Unit) {
        @JavascriptInterface fun VKCaptchaGetResult(json: String?) {
            if (json == null || json.length > 16384) {
                result("")
                return
            }
            val token = runCatching { JSONObject(json).optString("token", "") }.getOrDefault("")
            result(token.takeIf { it.isNotEmpty() && it.length <= 8192 }.orEmpty())
        }

        @JavascriptInterface fun VKCaptchaEscalate(ignored: String?) = result("")
        @JavascriptInterface fun VKCaptchaTokenExpired(ignored: String?) = result("")
        @JavascriptInterface fun VKCaptchaCloseCaptcha(ignored: String?) = result("")
    }

    private fun isCurrent(request: Request): Boolean = synchronized(lock) { !closed && current === request }

    private fun finish(request: Request, result: String) {
        val claimed = synchronized(lock) {
            if (current !== request) false else {
                current = null
                true
            }
        }
        if (!claimed) return
        deliver(request, result)
    }

    private fun deliver(request: Request, result: String) {
        onMain {
            val dialog = request.dialog
            request.dialog = null
            runCatching {
                dialog?.apply {
                    setOnCancelListener(null)
                    setOnDismissListener(null)
                    dismiss()
                }
            }
            val view = request.webView
            request.webView = null
            if (view != null) {
                runCatching { view.stopLoading() }
                runCatching { view.removeJavascriptInterface("AndroidBridge") }
                runCatching { (view.parent as? ViewGroup)?.removeView(view) }
                runCatching { view.destroy() }
            }
            val callback = request.onResult
            request.onResult = null
            runCatching { callback?.invoke(result) }
        }
    }

    private fun onMain(action: () -> Unit) {
        if (Looper.myLooper() == Looper.getMainLooper()) action() else main.post(action)
    }

    private companion object {
        private val vkHost = Regex("(?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\\.)*vk\\.(?:com|ru)")

        fun allowedVk(uri: Uri?): Boolean {
            val host = uri?.host?.lowercase(Locale.ROOT) ?: return false
            return uri.scheme == "https" && uri.userInfo == null && (uri.port == -1 || uri.port == 443) && vkHost.matches(host)
        }

        fun sdkTarget(raw: String): String? {
            if (raw.isBlank() || raw.length > 65536) return null
            return runCatching {
                val uri = Uri.parse(raw)
                if (!allowedVk(uri) || uri.path !in setOf("/not_robot_captcha", "/not_robot_captcha/")) return null
                val query = uri.encodedQuery.orEmpty().split('&').filter { part ->
                    part.isNotEmpty() && Uri.decode(part.substringBefore('=')) != "mode"
                }
                uri.buildUpon().encodedQuery((query + "mode=invisible").joinToString("&")).build().toString()
            }.getOrNull()
        }

        fun blocked(): WebResourceResponse = WebResourceResponse(
            "text/plain", "UTF-8", 403, "Blocked", emptyMap(), ByteArrayInputStream(byteArrayOf()),
        )
    }
}
