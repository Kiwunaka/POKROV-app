package space.pokrov.pokrov_android_shell

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.security.KeyChain
import android.util.Base64
import androidx.core.content.ContextCompat
import java.security.KeyStore

/** Publishes only a complete read from the current trust-store generation. */
internal class AndroidCertificateSnapshot(private val load: () -> List<String>) {
    private val stateLock = Any()
    private val loadLock = Any()
    private var generation = 0L
    private var cached: List<String>? = null

    fun read(): List<String> = synchronized(stateLock) { cached.orEmpty() }

    fun invalidate() = synchronized(stateLock) {
        generation++
        cached = null
    }

    fun prepare() {
        synchronized(loadLock) {
            val observed = synchronized(stateLock) {
                if (cached != null || Thread.currentThread().isInterrupted) return
                generation
            }
            val loaded = runCatching { load().toList() }.getOrNull() ?: return
            if (loaded.isEmpty() || Thread.currentThread().isInterrupted) return
            synchronized(stateLock) {
                if (generation == observed) cached = loaded
            }
        }
    }
}

/** Same AndroidCAStore DER roots as Core's JNI reader, prepared outside probe timers. */
internal object AndroidSystemCertificates {
    private val snapshot = AndroidCertificateSnapshot(::loadCertificates)
    private var registered = false
    private val receiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            snapshot.invalidate()
        }
    }

    fun read(): List<String> = snapshot.read()

    fun prepare(context: Context) {
        if (runCatching { register(context.applicationContext) }.isFailure) return
        snapshot.prepare()
    }

    @Synchronized
    @Suppress("DEPRECATION")
    private fun register(context: Context) {
        if (registered) return
        val action = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
            KeyChain.ACTION_TRUST_STORE_CHANGED else KeyChain.ACTION_STORAGE_CHANGED
        ContextCompat.registerReceiver(context, receiver, IntentFilter(action),
            ContextCompat.RECEIVER_NOT_EXPORTED)
        registered = true
    }

    private fun loadCertificates(): List<String> {
        val store = KeyStore.getInstance("AndroidCAStore")
        store.load(null, null)
        val aliases = store.aliases()
        val roots = ArrayList<String>()
        while (aliases.hasMoreElements()) {
            check(!Thread.currentThread().isInterrupted) { "certificate preparation interrupted" }
            val certificate = requireNotNull(store.getCertificate(aliases.nextElement()))
            val encoded = Base64.encodeToString(certificate.encoded, Base64.NO_WRAP)
            roots.add("-----BEGIN CERTIFICATE-----\n$encoded\n-----END CERTIFICATE-----\n")
        }
        return roots
    }
}
