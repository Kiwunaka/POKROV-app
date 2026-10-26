package space.pokrov.pokrov_android_shell

import android.content.Context
import android.net.DnsResolver
import android.os.Build
import android.os.CancellationSignal
import android.os.Handler
import android.os.SystemClock
import android.util.Log
import org.json.JSONObject
import space.pokrov.core.libbox.CommandServer
import space.pokrov.core.libbox.Libbox
import java.net.InetAddress
import java.time.Instant
import java.util.concurrent.CountDownLatch
import java.util.concurrent.Executor
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicReference

internal fun logLocalDpiDiagnostic(code: String) {
    Log.i("POKROV-LocalDPI", code)
}

internal data class LocalDpiVpnOutbound(
    val tag: String,
    val type: String,
    val detour: String = "",
    val upstreamTag: String = "",
    val children: List<String> = emptyList(),
)

/** Inspect the transport behind a lease, but keep the lease as the fallback. */
internal fun localDpiVpnFallback(
    outbounds: List<LocalDpiVpnOutbound>, tag: String, onFailure: (String) -> Unit = {},
): String? {
    fun rejected(reason: String): Boolean { onFailure(reason); return false }
    fun protected(candidate: String, visiting: Set<String>, missing: String): Boolean {
        if (candidate in visiting) return rejected("fallback=cycle")
        val outbound = outbounds.singleOrNull { it.tag == candidate }
            ?: return rejected(if (outbounds.any { it.tag == candidate }) "fallback=duplicate_target" else missing)
        if (outbound.detour.isNotEmpty()) {
            val targets = outbounds.filter { it.tag == outbound.detour }
            return rejected(when {
                targets.isEmpty() -> "fallback=detour_target_missing"
                targets.size != 1 -> "fallback=detour_target_duplicate"
                targets.single().type == "direct" -> "fallback=detour_direct"
                else -> "fallback=detour_other"
            })
        }
        val visited = visiting + candidate
        return when (outbound.type) {
            "vless", "hysteria2", "wireguard", "awg" -> true
            "pokrov-ats-lease" -> protected(outbound.upstreamTag, visited, "fallback=lease_target_missing")
            "selector", "urltest" -> if (outbound.children.isEmpty()) rejected("fallback=empty_group") else
                outbound.children.all { protected(it, visited, "fallback=group_target_missing") }
            "direct" -> rejected("fallback=type_direct")
            "block" -> rejected("fallback=type_block")
            "dns" -> rejected("fallback=type_dns")
            "naive" -> rejected("fallback=type_naive")
            "pokrov-smart-access" -> rejected("fallback=type_smart_access")
            "" -> rejected("fallback=type_empty")
            else -> rejected("fallback=type_other")
        }
    }
    return tag.takeIf { protected(it, emptySet(), "fallback=root_target_missing") }
}

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

    private fun start(strategy: AndroidByeDpiStrategy, port: Int = 0): AndroidByeDpiRuntime = try {
        AndroidByeDpiRuntime.startUnproven(context, child, ::current, protect, strategy, port) {
            if (!switchingStrategy) holders?.close()
        }
    } catch (failure: Exception) {
        logLocalDpiDiagnostic("native_start=failed")
        throw failure
    }

    fun publish(server: CommandServer, serverCurrent: () -> Boolean) {
        val captured = AndroidLocalDpiHolders(
            { current() && serverCurrent() },
            server::readLocalDpiAdmissionID, server::admitLocalDpiAdmission,
            { server.withdrawLocalDpiAdmission(it) },
            server::readLocalDpiObservation,
        )
        holders = captured
        child.onCancel(captured::close)
        if (!runCatching { captured.capture(tags) }.getOrDefault(false)) {
            logLocalDpiDiagnostic("holder_capture=failed")
            close()
            return
        }
        logLocalDpiDiagnostic("holder_capture=ok")
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
                            when {
                                !verifyAuthority(metadata, service, host) -> {
                                    logLocalDpiDiagnostic("proof=authority_rejected")
                                    false
                                }
                                !current() || !serverCurrent() -> {
                                    logLocalDpiDiagnostic("proof=scope_inactive")
                                    false
                                }
                                else -> {
                                    val address = resolve(host, ::attemptRemaining)
                                    if (address == null) {
                                        logLocalDpiDiagnostic("proof=address_unavailable")
                                        false
                                    } else {
                                        val proved = runtime!!.proveService(host, address, ::attemptRemaining)
                                        if (!proved) logLocalDpiDiagnostic("proof=transport_failed")
                                        proved
                                    }
                                }
                            }
                        }
                        if (!passed) {
                            logLocalDpiDiagnostic("proof=not_admitted")
                        } else if (!runtime!!.markAdmitted()) {
                            logLocalDpiDiagnostic("proof=owner_changed")
                            captured.withdrawService(service)
                        } else {
                            logLocalDpiDiagnostic("proof=admitted")
                        }
                    }
                    if (captured.hasAdmission()) {
                        AndroidByeDpiRuntime.rememberStrategy(networkRef, strategy)
                        return@execute
                    }
                }
                logLocalDpiDiagnostic("proof=exhausted")
                close()
            } catch (_: Exception) {
                logLocalDpiDiagnostic("proof=exception")
                close()
            }
        }) {
            logLocalDpiDiagnostic("proof=worker_unavailable")
            close()
        }
    }

    fun withdrawService(service: String) { holders?.withdrawService(service) }

    fun observationSummary(): String? = holders?.observationSummary()

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
        private fun unavailable(code: String): AndroidLocalDpiAdmission? {
            logLocalDpiDiagnostic(code)
            return null
        }

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

        fun prepare(context: Context, config: JSONObject, metadata: JSONObject?, parent: AndroidLifecycleTaskScope,
                    ownsProfile: () -> Boolean, protect: (Int) -> Boolean, handler: Handler,
                    proofBudgetMillis: () -> Int): AndroidLocalDpiAdmission? {
            if (metadata == null) return unavailable("prepare=metadata_absent")
            if (!BuildConfig.POKROV_ROUTING_CATALOG_ENABLED) return unavailable("prepare=build_disabled")
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return unavailable("prepare=android_unsupported")
            if (BuildConfig.POKROV_ROUTING_CATALOG_KEY_ID.isEmpty() ||
                BuildConfig.POKROV_ROUTING_CATALOG_PUBLIC_KEY_B64.isEmpty()) return unavailable("prepare=pin_missing")
            var result: AndroidLocalDpiAdmission? = null
            var failureCode = "prepare=core_exception"
            try {
                if (Libbox.localDpiAdmissionVersion() != 1) return unavailable("prepare=core_unsupported")
                if (metadata.getString("mode") != "selective" || metadata.getString("platform") != "android")
                    return unavailable("prepare=metadata_scope")
                if (!ownsProfile()) return unavailable("prepare=owner_changed")
                failureCode = "prepare=config_exception"
                val route = config.getJSONObject("route")
                val outbounds = config.getJSONArray("outbounds")
                val vpnOutbounds = (0 until outbounds.length()).mapNotNull(outbounds::optJSONObject).map { outbound ->
                    val children = outbound.optJSONArray("outbounds")
                    LocalDpiVpnOutbound(outbound.optString("tag"), outbound.optString("type"),
                        outbound.optString("detour"), outbound.optString("upstream_tag"),
                        if (children == null) emptyList() else (0 until children.length()).map(children::getString))
                }
                val direct = (0 until outbounds.length()).mapNotNull(outbounds::optJSONObject)
                    .singleOrNull { it.optString("tag") == route.optString("final") && it.optString("type") == "direct" }
                    ?: return unavailable("prepare=direct_missing")
                if (direct.optString("detour").isNotEmpty()) return unavailable("prepare=direct_detour")
                if ((config.optJSONArray("endpoints")?.length() ?: 0) != 0) return unavailable("prepare=endpoints_present")
                failureCode = "prepare=envelope_exception"
                val source = JSONObject(metadata.getString("catalog_envelope")).getJSONObject("payload")
                val sourceServices = source.getJSONArray("services")
                val wanted = metadata.getJSONObject("services")
                val controls = linkedMapOf<String, String>()
                val tags = linkedMapOf<String, String>()
                val replacements = mutableListOf<Pair<JSONObject, String>>()
                val fallbacks = linkedMapOf<String, String>()
                val rules = route.getJSONArray("rules")
                for (service in wanted.keys().asSequence().toList().sorted()) {
                    failureCode = "prepare=authority_exception"
                    val host = wanted.getString(service)
                    if (!verifyAuthority(metadata, service, host)) {
                        logLocalDpiDiagnostic("prepare=authority_rejected")
                        continue
                    }
                    failureCode = "prepare=rules_exception"
                    val original = (0 until sourceServices.length()).map(sourceServices::getJSONObject)
                        .single { it.getString("service_id") == service }
                    val domains = original.getJSONArray("domains")
                    val tag = "pokrov-local-dpi-$service"
                    if ((0 until outbounds.length()).any { outbounds.optJSONObject(it)?.optString("tag") == tag })
                        return unavailable("prepare=outbound_collision")
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
                        val vpn = localDpiVpnFallback(vpnOutbounds, rule.optString("outbound"), ::logLocalDpiDiagnostic)
                            ?: return unavailable("prepare=fallback_unprotected")
                        if (fallbacks[service] != null && fallbacks[service] != vpn)
                            return unavailable("prepare=fallback_conflict")
                        fallbacks[service] = vpn
                        replacements.add(rule to tag)
                    }
                    if (fallbacks.containsKey(service)) { controls[service] = host; tags[service] = tag }
                }
                if (controls.isEmpty()) return unavailable("prepare=no_matching_rules")
                failureCode = "prepare=network_exception"
                val generation = AndroidDefaultNetworkMonitor.contextGeneration()
                    ?: return unavailable("prepare=network_unavailable")
                val issued = Instant.parse(source.getString("issued_at"))
                val expires = Instant.parse(source.getString("expires_at"))
                val ttl = expires.toEpochMilli() - System.currentTimeMillis()
                if (ttl <= 0) return unavailable("prepare=catalog_expired")
                val child = AndroidLifecycleTaskScope(parent.generation, "pokrov-dpi", 1)
                parent.onCancel(child::close)
                val admission = AndroidLocalDpiAdmission(context, child, ownsProfile, protect, handler,
                    metadata, controls, tags, generation, issued, expires, SystemClock.elapsedRealtime() + ttl, proofBudgetMillis)
                result = admission
                child.onCancel { admission.holders?.close() }
                val networkObservation = AndroidDefaultNetworkMonitor.onContextInvalidated(admission::close)
                child.onCancel(networkObservation::close)
                failureCode = "prepare=native_start_exception"
                admission.runtime = admission.start(admission.strategyOrder.first())
                child.onCancel { admission.runtime?.close() }
                child.onCancel { handler.removeCallbacks(admission.expiry) }
                handler.postDelayed(admission.expiry, ttl)
                val port = admission.runtime!!.unprovenSocksPort
                if (!admission.current()) { admission.close(); return unavailable("prepare=scope_inactive") }
                failureCode = "prepare=outbound_exception"
                for ((service, tag) in tags) outbounds.put(JSONObject().put("type", "pokrov-local-dpi")
                    .put("tag", tag).put("server", "127.0.0.1").put("server_port", port)
                    .put("vpn_outbound", fallbacks.getValue(service)).put("service_id", service)
                    .put("prefer_tcp", service == "youtube"))
                replacements.forEach { (rule, tag) -> rule.put("outbound", tag) }
                logLocalDpiDiagnostic("prepare=ok")
                return result
            } catch (_: Exception) {
                result?.close()
                return unavailable(failureCode)
            }
        }
    }
}
