package space.pokrov.pokrov_android_shell

import android.net.DnsResolver
import android.os.Build
import android.os.CancellationSignal
import android.system.ErrnoException
import android.util.Log
import androidx.annotation.RequiresApi
import io.nekohasekai.libbox.ExchangeContext
import io.nekohasekai.libbox.LocalDNSTransport
import java.net.InetAddress
import java.net.UnknownHostException
import java.util.concurrent.CountDownLatch
import java.util.concurrent.Executor
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicReference
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.asExecutor

internal object AndroidLocalResolver : LocalDNSTransport {
    private const val RCODE_NXDOMAIN = 3
    private val resolverExecutor: Executor = Dispatchers.IO.asExecutor()

    override fun raw(): Boolean {
        return Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q
    }

    @RequiresApi(Build.VERSION_CODES.Q)
    override fun exchange(ctx: ExchangeContext, message: ByteArray) {
        val defaultNetwork = requireDefaultNetwork(queryFamily = "raw")
        val signal = CancellationSignal()
        val failure = AtomicReference<Throwable?>(null)
        val latch = CountDownLatch(1)
        ctx.onCancel(signal::cancel)
        Log.i(
            LOG_TAG,
            "Resolver rawQuery family=raw network=$defaultNetwork bytes=${message.size}",
        )
        val callback = object : DnsResolver.Callback<ByteArray> {
            override fun onAnswer(answer: ByteArray, rcode: Int) {
                if (rcode == 0) {
                    AndroidRuntimeState.markDnsOperational()
                    ctx.rawSuccess(answer)
                } else {
                    ctx.errorCode(rcode)
                }
                latch.countDown()
            }

            override fun onError(error: DnsResolver.DnsException) {
                val failureKind = classifyResolverFailure(error)
                Log.w(
                    LOG_TAG,
                    "Resolver rawQuery failed family=raw kind=$failureKind network=$defaultNetwork",
                    error,
                )
                AndroidRuntimeState.recordFailureKind(failureKind)
                AndroidRuntimeState.markDegraded(
                    failureKind = failureKind,
                    message = "Android tun is established, but local DNS resolution is degraded ($failureKind).",
                )
                when (val cause = error.cause) {
                    is ErrnoException -> ctx.errnoCode(cause.errno)
                    else -> failure.set(error)
                }
                latch.countDown()
            }
        }
        DnsResolver.getInstance().rawQuery(
            defaultNetwork,
            message,
            DnsResolver.FLAG_NO_RETRY,
            resolverExecutor,
            signal,
            callback,
        )
        await(latch, signal)
        failure.get()?.let { throw it }
    }

    override fun lookup(ctx: ExchangeContext, network: String, domain: String) {
        val queryFamily = queryFamily(network)
        val defaultNetwork = requireDefaultNetwork(queryFamily = queryFamily)
        Log.i(
            LOG_TAG,
            "Resolver lookup family=$queryFamily domain=$domain network=$defaultNetwork",
        )
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val signal = CancellationSignal()
            val failure = AtomicReference<Throwable?>(null)
            val latch = CountDownLatch(1)
            ctx.onCancel(signal::cancel)
            val callback = object : DnsResolver.Callback<Collection<InetAddress>> {
                override fun onAnswer(answer: Collection<InetAddress>, rcode: Int) {
                    if (rcode == 0) {
                        AndroidRuntimeState.markDnsOperational()
                        ctx.success(answer.mapNotNull { it.hostAddress }.joinToString("\n"))
                    } else {
                        ctx.errorCode(rcode)
                    }
                    latch.countDown()
                }

                override fun onError(error: DnsResolver.DnsException) {
                    val failureKind = classifyResolverFailure(error)
                    Log.w(
                        LOG_TAG,
                        "Resolver lookup failed family=$queryFamily domain=$domain kind=$failureKind network=$defaultNetwork",
                        error,
                    )
                    AndroidRuntimeState.recordFailureKind(failureKind)
                    AndroidRuntimeState.markDegraded(
                        failureKind = failureKind,
                        message = "Android tun is established, but local DNS resolution is degraded ($failureKind).",
                    )
                    when (val cause = error.cause) {
                        is ErrnoException -> ctx.errnoCode(cause.errno)
                        else -> failure.set(error)
                    }
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
                    DnsResolver.FLAG_NO_RETRY,
                    resolverExecutor,
                    signal,
                    callback,
                )
            } else {
                DnsResolver.getInstance().query(
                    defaultNetwork,
                    domain,
                    DnsResolver.FLAG_NO_RETRY,
                    resolverExecutor,
                    signal,
                    callback,
                )
            }
            await(latch, signal)
            failure.get()?.let { throw it }
            return
        }

        val answer = try {
            defaultNetwork.getAllByName(domain)
        } catch (_: UnknownHostException) {
            Log.w(
                LOG_TAG,
                "Resolver legacy lookup failed family=$queryFamily domain=$domain kind=resolver_nxdomain network=$defaultNetwork",
            )
            AndroidRuntimeState.recordFailureKind("resolver_nxdomain")
            AndroidRuntimeState.markDegraded(
                failureKind = "resolver_nxdomain",
                message = "Android tun is established, but local DNS resolution is degraded (resolver_nxdomain).",
            )
            ctx.errorCode(RCODE_NXDOMAIN)
            return
        }
        AndroidRuntimeState.markDnsOperational()
        ctx.success(answer.mapNotNull { it.hostAddress }.joinToString("\n"))
    }

    private fun await(latch: CountDownLatch, signal: CancellationSignal) {
        while (!signal.isCanceled) {
            if (latch.await(250, TimeUnit.MILLISECONDS)) {
                return
            }
        }
    }

    private fun requireDefaultNetwork(queryFamily: String): android.net.Network {
        return try {
            AndroidDefaultNetworkMonitor.require()
        } catch (error: IllegalStateException) {
            Log.w(
                LOG_TAG,
                "Resolver cannot start family=$queryFamily kind=default_network_unavailable",
                error,
            )
            AndroidRuntimeState.recordFailureKind("default_network_unavailable")
            AndroidRuntimeState.markDegraded(
                failureKind = "default_network_unavailable",
                message = "Android tun is established, but no non-VPN default uplink is ready for DNS resolution.",
            )
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
            is ErrnoException -> "resolver_errno_${cause.errno}"
            is UnknownHostException -> "resolver_unknown_host"
            else -> "resolver_dns_exception"
        }
    }

    private const val LOG_TAG = "PokrovResolver"
}
