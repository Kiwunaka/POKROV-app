package space.pokrov.pokrov_android_shell

import android.content.Context
import android.net.DnsResolver
import android.os.Build
import android.os.CancellationSignal
import android.os.Handler
import android.os.SystemClock
import org.json.JSONObject
import space.pokrov.core.libbox.CommandServer
import space.pokrov.core.libbox.Libbox
import java.net.InetAddress
import java.time.Instant
import java.util.concurrent.CountDownLatch
import java.util.concurrent.Executor
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicReference

/** One global ByeDPI child, restricted to signed service routes of one profile. */
internal class AndroidLocalDpiAdmission private constructor(
    private val context: Context,
    private val child: AndroidLifecycleTaskScope,
    private val ownerCurrent: () -> Boolean,
    private val protect: (Int) -> Boolean,
    private val handler: Handler,
    private val metadata: JSONObject,
    private val services: Map<String, String>,
    private val tags: Map<String, String>,
    private val networkGeneration: Long,
    private val issued: Instant,
    private val expires: Instant,
    private val ttlDeadline: Long,
    private val proofBudgetMillis: () -> Int,
) : AutoCloseable {
    private val networkRef = "android-dpi:$networkGeneration"
    private val strategyOrder = AndroidByeDpiRuntime.strategyOrder(networkRef)
    @Volatile private var runtime: AndroidByeDpiRuntime? = null
    @Volatile private var holders: AndroidLocalDpiHolders? = null
    @Volatile private var switchingStrategy = false
    private val expiry = Runnable { close() }

    private fun current(): Boolean {
        val now = Instant.now()
        return child.isActive() && ownerCurrent() &&
            AndroidDefaultNetworkMonitor.contextGeneration() == networkGeneration &&
            !now.isBefore(issued) && now.isBefore(expires) && SystemClock.elapsedRealtime() < ttlDeadline
    }

    private fun start(strategy: AndroidByeDpiStrategy, port: Int = 0): AndroidByeDpiRuntime =
        AndroidByeDpiRuntime.startUnproven(context, child, ::current, protect, strategy, port) {
            if (!switchingStrategy) holders?.close()
        }

    fun publish(server: CommandServer, serverCurrent: () -> Boolean) {
        val captured = AndroidLocalDpiHolders(
            { current() && serverCurrent() },
            server::readLocalDpiAdmissionID, server::admitLocalDpiAdmission,
            { server.withdrawLocalDpiAdmission(it) },
        )
        holders = captured
        child.onCancel(captured::close)
        if (!runCatching { captured.capture(tags) }.getOrDefault(false)) { close(); return }
        if (!child.execute {
            val started = SystemClock.elapsedRealtime()
            val budget = proofBudgetMillis()
            fun remaining(): Int = minOf(proofBudgetMillis(),
                (budget - (SystemClock.elapsedRealtime() - started)).toInt())
            try {
                for ((index, strategy) in strategyOrder.withIndex()) {
                    if (!current() || !serverCurrent() || remaining() <= 0) break
                    if (index != 0) {
                        // All holders remain dormant; the second strategy keeps
                        // the already configured loopback port and identities.
                        check(!captured.hasAdmission())
                        val port = runtime!!.unprovenSocksPort
                        switchingStrategy = true
                        try { runtime!!.close(); runtime = start(strategy, port) }
                        finally { switchingStrategy = false }
                    }
                    val deadline = SystemClock.elapsedRealtime() + remaining() / (strategyOrder.size - index)
                    fun attemptRemaining() = minOf(remaining(), (deadline - SystemClock.elapsedRealtime()).toInt())
                    for ((service, host) in services) {
                        if (!current() || !serverCurrent() || attemptRemaining() <= 0) break
                        val passed = captured.publish(service) {
                            // Repeat original signature/scope/TTL verification
                            // after Core start, immediately before any proof.
                            verifyAuthority(metadata, service, host) && current() && serverCurrent() &&
                                resolve(host, ::attemptRemaining)?.let { address ->
                                    runtime!!.proveService(host, address, ::attemptRemaining)
                                } == true
                        }
                        if (passed && !runtime!!.markAdmitted()) captured.withdrawService(service)
                    }
                    if (captured.hasAdmission()) {
                        AndroidByeDpiRuntime.rememberStrategy(networkRef, strategy)
                        return@execute
                    }
                }
                close()
            } catch (_: Exception) { close() }
        }) close()
    }

    fun withdrawService(service: String) { holders?.withdrawService(service) }

    private fun resolve(host: String, remaining: () -> Int): InetAddress? {
        if (!current() || remaining() <= 0) return null
        val signal = CancellationSignal()
        val ready = CountDownLatch(1)
        val address = AtomicReference<InetAddress?>()
        child.onCancel { signal.cancel(); ready.countDown() }
        try {
            DnsResolver.getInstance().query(AndroidDefaultNetworkMonitor.require(), host,
                AndroidResolverPolicy.QUERY_FLAGS, Executor { it.run() }, signal,
                object : DnsResolver.Callback<Collection<InetAddress>> {
                    override fun onAnswer(answer: Collection<InetAddress>, rcode: Int) {
                        if (rcode == 0 && !signal.isCanceled) address.set(answer.firstOrNull(::publicAddress))
                        ready.countDown()
                    }
                    override fun onError(error: DnsResolver.DnsException) { ready.countDown() }
                })
            return if (ready.await(remaining().coerceAtLeast(0).toLong(), TimeUnit.MILLISECONDS) && current()) address.get() else null
        } finally { signal.cancel() }
    }

    override fun close() { child.close() }

    companion object {
        private fun verifyAuthority(metadata: JSONObject, service: String, host: String): Boolean =
            Libbox.verifyLocalDpiCatalog(metadata.getString("catalog_envelope"),
                JSONObject().put(BuildConfig.POKROV_ROUTING_CATALOG_KEY_ID,
                    BuildConfig.POKROV_ROUTING_CATALOG_PUBLIC_KEY_B64).toString(),
                BuildConfig.POKROV_ROUTING_CATALOG_AUDIENCE, metadata.getString("catalog_sha256"),
                metadata.getLong("revision"), metadata.getLong("security_revision"),
                service, host, metadata.getString("access_state"))

        private fun publicAddress(address: InetAddress): Boolean =
            !address.isAnyLocalAddress && !address.isLoopbackAddress && !address.isLinkLocalAddress &&
                !address.isSiteLocalAddress && !address.isMulticastAddress &&
                !(address.address.size == 16 && (address.address[0].toInt() and 0xfe) == 0xfc)

        private fun protectedDirectVpn(config: JSONObject, tag: String, visiting: MutableSet<String> = mutableSetOf()): Boolean {
            if (!visiting.add(tag)) return false
            val rows = config.optJSONArray("outbounds") ?: return false
            val outbound = (0 until rows.length()).mapNotNull(rows::optJSONObject).singleOrNull { it.optString("tag") == tag } ?: return false
            if (outbound.optString("detour").isNotEmpty()) return false
            return when (outbound.optString("type")) {
                "vless", "hysteria2", "wireguard", "awg" -> true
                "selector", "urltest" -> {
                    val group = outbound.optJSONArray("outbounds") ?: return false
                    group.length() > 0 && (0 until group.length()).all { protectedDirectVpn(config, group.getString(it), visiting.toMutableSet()) }
                }
                else -> false
            }
        }

        fun prepare(context: Context, config: JSONObject, metadata: JSONObject?, parent: AndroidLifecycleTaskScope,
                    ownsProfile: () -> Boolean, protect: (Int) -> Boolean, handler: Handler,
                    proofBudgetMillis: () -> Int): AndroidLocalDpiAdmission? {
            if (metadata == null || !BuildConfig.POKROV_ROUTING_CATALOG_ENABLED ||
                Build.VERSION.SDK_INT < Build.VERSION_CODES.Q ||
                BuildConfig.POKROV_ROUTING_CATALOG_KEY_ID.isEmpty() ||
                BuildConfig.POKROV_ROUTING_CATALOG_PUBLIC_KEY_B64.isEmpty()) return null
            var result: AndroidLocalDpiAdmission? = null
            try {
                if (Libbox.localDpiAdmissionVersion() != 1 || metadata.getString("mode") != "selective" ||
                    metadata.getString("platform") != "android" || !ownsProfile()) return null
                val route = config.getJSONObject("route")
                val outbounds = config.getJSONArray("outbounds")
                val direct = (0 until outbounds.length()).mapNotNull(outbounds::optJSONObject)
                    .singleOrNull { it.optString("tag") == route.optString("final") && it.optString("type") == "direct" } ?: return null
                if (direct.optString("detour").isNotEmpty() || (config.optJSONArray("endpoints")?.length() ?: 0) != 0) return null
                val source = JSONObject(metadata.getString("catalog_envelope")).getJSONObject("payload")
                val sourceServices = source.getJSONArray("services")
                val wanted = metadata.getJSONObject("services")
                val controls = linkedMapOf<String, String>()
                val tags = linkedMapOf<String, String>()
                val replacements = mutableListOf<Pair<JSONObject, String>>()
                val fallbacks = linkedMapOf<String, String>()
                val rules = route.getJSONArray("rules")
                for (service in wanted.keys().asSequence().toList().sorted()) {
                    val host = wanted.getString(service)
                    if (!verifyAuthority(metadata, service, host)) continue
                    val original = (0 until sourceServices.length()).map(sourceServices::getJSONObject)
                        .single { it.getString("service_id") == service }
                    val domains = original.getJSONArray("domains")
                    val tag = "pokrov-local-dpi-$service"
                    if ((0 until outbounds.length()).any { outbounds.optJSONObject(it)?.optString("tag") == tag }) return null
                    for (index in 0 until rules.length()) {
                        val rule = rules.optJSONObject(index) ?: continue
                        val window = rule.optJSONObject("pokrov_catalog_window") ?: continue
                        if (window.optString("service_id") != service || rule.optString("action") != "route" ||
                            window.optString("issued_at") != source.getString("issued_at") ||
                            window.optString("expires_at") != source.getString("expires_at") || window.has("lease_id")) continue
                        val suffix = rule.has("domain_suffix")
                        val names = rule.optJSONArray(if (suffix) "domain_suffix" else "domain") ?: continue
                        if (names.length() != 1 || !(0 until domains.length()).any {
                            val domain = domains.getJSONObject(it)
                            domain.getString("name") == names.getString(0) && !domain.getBoolean("shared") &&
                                domain.getString("match") == if (suffix) "suffix" else "exact"
                        }) continue
                        val vpn = rule.optString("outbound")
                        if (!protectedDirectVpn(config, vpn) || (fallbacks[service] != null && fallbacks[service] != vpn)) return null
                        fallbacks[service] = vpn
                        replacements.add(rule to tag)
                    }
                    if (fallbacks.containsKey(service)) { controls[service] = host; tags[service] = tag }
                }
                if (controls.isEmpty()) return null
                val generation = AndroidDefaultNetworkMonitor.contextGeneration() ?: return null
                val issued = Instant.parse(source.getString("issued_at"))
                val expires = Instant.parse(source.getString("expires_at"))
                val ttl = expires.toEpochMilli() - System.currentTimeMillis()
                if (ttl <= 0) return null
                val child = AndroidLifecycleTaskScope(parent.generation, "pokrov-dpi", 1)
                parent.onCancel(child::close)
                val admission = AndroidLocalDpiAdmission(context, child, ownsProfile, protect, handler,
                    metadata, controls, tags, generation, issued, expires, SystemClock.elapsedRealtime() + ttl, proofBudgetMillis)
                result = admission
                child.onCancel { admission.holders?.close() }
                val networkObservation = AndroidDefaultNetworkMonitor.onContextInvalidated(admission::close)
                child.onCancel(networkObservation::close)
                admission.runtime = admission.start(admission.strategyOrder.first())
                child.onCancel { admission.runtime?.close() }
                child.onCancel { handler.removeCallbacks(admission.expiry) }
                handler.postDelayed(admission.expiry, ttl)
                val port = admission.runtime!!.unprovenSocksPort
                if (!admission.current()) { admission.close(); return null }
                for ((service, tag) in tags) outbounds.put(JSONObject().put("type", "pokrov-local-dpi")
                    .put("tag", tag).put("server", "127.0.0.1").put("server_port", port)
                    .put("vpn_outbound", fallbacks.getValue(service)).put("service_id", service))
                replacements.forEach { (rule, tag) -> rule.put("outbound", tag) }
                return result
            } catch (_: Exception) { result?.close(); return null }
        }
    }
}
