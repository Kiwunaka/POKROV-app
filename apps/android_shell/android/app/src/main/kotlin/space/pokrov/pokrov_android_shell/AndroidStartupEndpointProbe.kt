package space.pokrov.pokrov_android_shell

import android.content.Context
import android.net.ConnectivityManager
import android.net.DnsResolver
import android.net.NetworkCapabilities
import android.os.Build
import android.os.CancellationSignal
import android.os.SystemClock
import java.io.IOException
import java.net.ConnectException
import java.net.InetAddress
import java.net.InetSocketAddress
import java.net.Socket
import java.net.SocketTimeoutException
import java.net.UnknownHostException
import java.util.concurrent.CountDownLatch
import java.util.concurrent.Executor
import java.util.concurrent.TimeUnit
import java.util.concurrent.TimeoutException
import java.util.concurrent.atomic.AtomicReference

/** Startup reachability only, with one budget for queueing, DNS and TCP. */
internal object AndroidStartupEndpointProbe {
    fun run(
        context: Context,
        scope: AndroidLifecycleTaskScope,
        ownsSession: () -> Boolean,
        server: String,
        port: Int,
        timeoutMillis: Int,
    ): String {
        val deadline = SystemClock.elapsedRealtime() + timeoutMillis
        val result = AtomicReference<String?>(null)
        val resultReady = CountDownLatch(1)
        val addressResult = AtomicReference<InetAddress?>(null)
        val addressReady = CountDownLatch(1)
        val signal = CancellationSignal()
        val socket = Socket()
        fun remaining(): Long = (deadline - SystemClock.elapsedRealtime()).also {
            if (it <= 0) throw TimeoutException()
        }
        fun finish(category: String) {
            if (result.compareAndSet(null, category)) resultReady.countDown()
        }
        scope.onCancel {
            signal.cancel()
            runCatching { socket.close() }
            addressReady.countDown()
            finish("cancelled")
        }
        val accepted = scope.execute {
            val category = try {
                if (!ownsSession()) {
                    "cancelled"
                } else {
                    val manager = context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
                    val network = manager.activeNetwork
                    val capabilities = network?.let(manager::getNetworkCapabilities)
                    when {
                        network == null -> "network_unavailable"
                        capabilities == null -> "capabilities_unavailable"
                        !capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_NOT_VPN) -> "active_network_is_vpn"
                        else -> {
                            remaining()
                            val address = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                                DnsResolver.getInstance().query(
                                    network, server, AndroidResolverPolicy.QUERY_FLAGS,
                                    Executor { it.run() }, signal,
                                    object : DnsResolver.Callback<Collection<InetAddress>> {
                                        override fun onAnswer(answer: Collection<InetAddress>, rcode: Int) {
                                            addressResult.set(if (rcode == 0) answer.firstOrNull() else null)
                                            addressReady.countDown()
                                        }
                                        override fun onError(error: DnsResolver.DnsException) {
                                            addressReady.countDown()
                                        }
                                    },
                                )
                                if (!addressReady.await(remaining(), TimeUnit.MILLISECONDS)) throw TimeoutException()
                                addressResult.get()
                            } else {
                                // Older Android DNS is not natively cancellable.
                                // It stays off the serial runtime owner; its late
                                // result cannot open a socket or publish success.
                                network.getAllByName(server).firstOrNull()
                            }
                            when {
                                !ownsSession() || result.get() != null -> "cancelled"
                                address == null -> "dns_unresolved"
                                else -> {
                                    network.bindSocket(socket)
                                    socket.connect(InetSocketAddress(address, port), remaining().toInt())
                                    if (ownsSession() && result.get() == null) "reachable" else "cancelled"
                                }
                            }
                        }
                    }
                }
            } catch (_: TimeoutException) {
                "timeout"
            } catch (_: SocketTimeoutException) {
                "timeout"
            } catch (_: UnknownHostException) {
                "dns_unresolved"
            } catch (_: ConnectException) {
                "connect_error"
            } catch (_: SecurityException) {
                "security_error"
            } catch (_: IOException) {
                "io_error"
            } catch (_: InterruptedException) {
                Thread.currentThread().interrupt()
                "cancelled"
            } catch (_: Exception) {
                if (ownsSession()) "runtime_error" else "cancelled"
            }
            finish(category)
        }
        if (!accepted) finish("cancelled")
        return try {
            if (!resultReady.await(remaining(), TimeUnit.MILLISECONDS)) throw TimeoutException()
            checkNotNull(result.get())
        } catch (_: TimeoutException) {
            finish("timeout")
            "timeout"
        } catch (_: InterruptedException) {
            Thread.currentThread().interrupt()
            finish("cancelled")
            "cancelled"
        } finally {
            signal.cancel()
            addressReady.countDown()
            runCatching { socket.close() }
        }
    }
}
