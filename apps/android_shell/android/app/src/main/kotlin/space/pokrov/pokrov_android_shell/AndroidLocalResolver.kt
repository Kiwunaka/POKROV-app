package space.pokrov.pokrov_android_shell

import android.net.DnsResolver
import android.os.Build
import android.os.CancellationSignal
import android.system.ErrnoException
import android.util.Log
import androidx.annotation.RequiresApi
import space.pokrov.core.libbox.ExchangeContext
import space.pokrov.core.libbox.LocalDNSTransport
import java.net.InetAddress
import java.net.UnknownHostException
import java.util.concurrent.CountDownLatch
import java.util.concurrent.Executor
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.asExecutor

internal object AndroidLocalResolver : LocalDNSTransport {
    private const val RCODE_NXDOMAIN = 3
    private val resolverExecutor: Executor = Dispatchers.IO.asExecutor()
    @Volatile
    private var activeRuntimeToken: Any? = null

    internal fun activateRuntime(token: Any) {
        activeRuntimeToken = token
    }

    internal fun deactivateRuntime(token: Any) {
        if (activeRuntimeToken === token) {
            activeRuntimeToken = null
        }
    }

    override fun raw(): Boolean {
        return Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q
    }

    @RequiresApi(Build.VERSION_CODES.Q)
    override fun exchange(ctx: ExchangeContext, message: ByteArray) {
        val runtimeToken = activeRuntimeToken
        val defaultNetwork = requireDefaultNetwork(queryFamily = "raw", runtimeToken = runtimeToken)
        val signal = CancellationSignal()
        val latch = CountDownLatch(1)
        val completed = AtomicBoolean(false)
        ctx.onCancel(signal::cancel)
        val callback = object : DnsResolver.Callback<ByteArray> {
            override fun onAnswer(answer: ByteArray, rcode: Int) {
                if (signal.isCanceled) {
                    latch.countDown()
                    return
                }
                if (!completed.compareAndSet(false, true)) {
                    return
                }
                if (rcode == 0) {
                    AndroidRuntimeState.markDnsOperational()
                    ctx.rawSuccess(answer)
                } else {
                    reportResult(AndroidResolverPolicy.RESPONSE_ERROR)
                    ctx.errorCode(rcode)
                }
                latch.countDown()
            }

            override fun onError(error: DnsResolver.DnsException) {
                if (signal.isCanceled) {
                    latch.countDown()
                    return
                }
                if (!completed.compareAndSet(false, true)) {
                    return
                }
                when (val cause = error.cause) {
                    is ErrnoException -> ctx.errnoCode(cause.errno)
                    else -> ctx.errorCode(AndroidResolverPolicy.SERVFAIL_RCODE)
                }
                reportTransportFailure(classifyResolverFailure(error), runtimeToken)
                latch.countDown()
            }
        }
        DnsResolver.getInstance().rawQuery(
            defaultNetwork,
            message,
            AndroidResolverPolicy.QUERY_FLAGS,
            resolverExecutor,
            signal,
            callback,
        )
        completeTimeoutIfNeeded(latch, signal, completed, ctx, runtimeToken)
    }

    override fun lookup(ctx: ExchangeContext, network: String, domain: String) {
        val queryFamily = queryFamily(network)
        val runtimeToken = activeRuntimeToken
        val defaultNetwork = requireDefaultNetwork(
            queryFamily = queryFamily,
            runtimeToken = runtimeToken,
        )
        Log.i(
            LOG_TAG,
            "Resolver lookup family=$queryFamily",
        )
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val signal = CancellationSignal()
            val latch = CountDownLatch(1)
            val completed = AtomicBoolean(false)
            ctx.onCancel(signal::cancel)
            val callback = object : DnsResolver.Callback<Collection<InetAddress>> {
                override fun onAnswer(answer: Collection<InetAddress>, rcode: Int) {
                    if (signal.isCanceled) {
                        latch.countDown()
                        return
                    }
                    if (!completed.compareAndSet(false, true)) {
                        return
                    }
                    if (rcode == 0) {
                        AndroidRuntimeState.markDnsOperational()
                        ctx.success(answer.mapNotNull { it.hostAddress }.joinToString("\n"))
                    } else {
                        reportResult(AndroidResolverPolicy.RESPONSE_ERROR)
                        ctx.errorCode(rcode)
                    }
                    latch.countDown()
                }

                override fun onError(error: DnsResolver.DnsException) {
                    if (signal.isCanceled) {
                        latch.countDown()
                        return
                    }
                    if (!completed.compareAndSet(false, true)) {
                        return
                    }
                    when (val cause = error.cause) {
                        is ErrnoException -> ctx.errnoCode(cause.errno)
                        else -> ctx.errorCode(AndroidResolverPolicy.SERVFAIL_RCODE)
                    }
                    reportTransportFailure(classifyResolverFailure(error), runtimeToken)
                    latch.countDown()
                }
            }
            val type = when {
                network.endsWith("4") -> DnsResolver.TYPE_A
                network.endsWith("6") -> DnsResolver.TYPE_AAAA
                else -> null
            }
            if (type != null) {
                DnsResolver.getInstance().query(
                    defaultNetwork,
                    domain,
                    type,
                    AndroidResolverPolicy.QUERY_FLAGS,
                    resolverExecutor,
                    signal,
                    callback,
                )
            } else {
                DnsResolver.getInstance().query(
                    defaultNetwork,
                    domain,
                    AndroidResolverPolicy.QUERY_FLAGS,
                    resolverExecutor,
                    signal,
                    callback,
                )
            }
            completeTimeoutIfNeeded(latch, signal, completed, ctx, runtimeToken)
            return
        }

        val answer = try {
            defaultNetwork.getAllByName(domain)
        } catch (_: UnknownHostException) {
            Log.w(
                LOG_TAG,
                "Resolver legacy lookup failed family=$queryFamily kind=resolver_nxdomain",
            )
            ctx.errorCode(RCODE_NXDOMAIN)
            return
        }
        AndroidRuntimeState.markDnsOperational()
        ctx.success(answer.mapNotNull { it.hostAddress }.joinToString("\n"))
    }

    private fun completeTimeoutIfNeeded(
        latch: CountDownLatch,
        signal: CancellationSignal,
        completed: AtomicBoolean,
        ctx: ExchangeContext,
        runtimeToken: Any?,
    ) {
        if (await(latch, signal) || signal.isCanceled || !completed.compareAndSet(false, true)) {
            return
        }
        signal.cancel()
        reportTransportFailure(AndroidResolverPolicy.TIMEOUT, runtimeToken)
        ctx.errorCode(AndroidResolverPolicy.SERVFAIL_RCODE)
        latch.countDown()
    }

    private fun await(latch: CountDownLatch, signal: CancellationSignal): Boolean {
        var remainingMillis = AndroidResolverPolicy.RESPONSE_WAIT_MILLIS
        while (!signal.isCanceled) {
            val waitMillis = minOf(250L, remainingMillis)
            if (latch.await(waitMillis, TimeUnit.MILLISECONDS)) {
                return true
            }
            remainingMillis -= waitMillis
            if (remainingMillis <= 0) {
                return false
            }
        }
        return false
    }

    private fun requireDefaultNetwork(
        queryFamily: String,
        runtimeToken: Any?,
    ): android.net.Network {
        return try {
            AndroidDefaultNetworkMonitor.require()
        } catch (error: IllegalStateException) {
            Log.w(
                LOG_TAG,
                "Resolver cannot start family=$queryFamily kind=default_network_unavailable",
            )
            AndroidRuntimeState.recordFailureKind("default_network_unavailable")
            AndroidRuntimeState.markDegraded(
                failureKind = "default_network_unavailable",
                message = "Android подключил POKROV, но обычная сеть устройства еще не готова для DNS.",
            )
            reportTransportFailure("default_network_unavailable", runtimeToken)
            throw error
        }
    }

    private fun queryFamily(network: String): String {
        return when {
            network.endsWith("4") -> "ipv4"
            network.endsWith("6") -> "ipv6"
            else -> "auto"
        }
    }

    private fun classifyResolverFailure(error: Throwable): String {
        return when (val cause = error.cause) {
            is ErrnoException -> AndroidResolverPolicy.CALLBACK_ERROR
            is UnknownHostException -> AndroidResolverPolicy.CALLBACK_ERROR
            else -> AndroidResolverPolicy.CALLBACK_ERROR
        }
    }

    private fun reportResult(kind: String) {
        Log.w(LOG_TAG, "Resolver result=$kind")
    }

    private fun reportTransportFailure(kind: String, runtimeToken: Any?) {
        reportResult(kind)
        val outcome = when (kind) {
            AndroidResolverPolicy.CALLBACK_ERROR -> AndroidResolverPolicy.RuntimeOutcome.CALLBACK_ERROR
            AndroidResolverPolicy.TIMEOUT,
            "default_network_unavailable" -> AndroidResolverPolicy.RuntimeOutcome.TIMEOUT
            else -> AndroidResolverPolicy.RuntimeOutcome.RESPONSE_RCODE
        }
        if (
            runtimeToken != null &&
                AndroidResolverPolicy.shouldFailCloseRuntime(outcome)
        ) {
            PokrovRuntimeVpnService.reportDnsTransportFailure(runtimeToken, kind)
        }
    }

    private const val LOG_TAG = "PokrovResolver"
}
