package space.pokrov.pokrov_android_shell

import android.net.DnsResolver
import android.net.LinkProperties
import android.net.Network
import android.os.Build
import android.os.CancellationSignal
import android.os.ParcelFileDescriptor
import space.pokrov.core.libbox.ConnectionOwner
import space.pokrov.core.libbox.ExchangeContext
import space.pokrov.core.libbox.InterfaceUpdateListener
import space.pokrov.core.libbox.LocalDNSTransport
import space.pokrov.core.libbox.NetworkInterfaceIterator
import space.pokrov.core.libbox.Notification
import space.pokrov.core.libbox.PlatformInterface
import space.pokrov.core.libbox.StringIterator
import space.pokrov.core.libbox.TunOptions
import space.pokrov.core.libbox.WIFIState
import java.net.InetAddress
import java.net.NetworkInterface
import java.net.DatagramPacket
import java.net.DatagramSocket
import java.net.InetSocketAddress
import java.net.Socket
import java.io.Closeable
import java.io.DataInputStream
import java.io.DataOutputStream
import java.util.concurrent.CountDownLatch
import java.util.concurrent.Executor
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicReference

/** Probe-owned platform facade. It never enters the runtime's monitor, resolver or TUN. */
internal class AndroidCandidateProbePlatform(
    private val network: Network,
    private val links: LinkProperties,
    private val isCancelled: () -> Boolean,
) : PlatformInterface {
    private val resolver = CapturedNetworkResolver(network, links.dnsServers, isCancelled)

    override fun autoDetectInterfaceControl(fd: Int) {
        check(!isCancelled()) { "candidate cancelled" }
        PokrovRuntimeVpnService.protectCandidateSocket(fd)
        // fromFd duplicates the descriptor; closing this wrapper does not close Core's socket.
        ParcelFileDescriptor.fromFd(fd).use { network.bindSocket(it.fileDescriptor) }
    }

    override fun openTun(options: TunOptions): Int = error("candidate probes cannot own a TUN")
    override fun usePlatformAutoDetectInterfaceControl(): Boolean = true
    override fun useProcFS(): Boolean = false
    override fun underNetworkExtension(): Boolean = false
    override fun includeAllNetworks(): Boolean = false
    override fun clearDNSCache() = Unit
    override fun readWIFIState(): WIFIState? = null
    override fun localDNSTransport(): LocalDNSTransport = resolver
    override fun systemCertificates(): StringIterator = ProbeStringIterator(emptyList())
    override fun sendNotification(notification: Notification) = Unit
    override fun findConnectionOwner(ipProtocol: Int, sourceAddress: String, sourcePort: Int,
        destinationAddress: String, destinationPort: Int): ConnectionOwner =
        ConnectionOwner().apply { setUserId(-1) }

    override fun startDefaultInterfaceMonitor(listener: InterfaceUpdateListener) {
        check(!isCancelled()) { "candidate cancelled" }
        val name = links.interfaceName ?: error("candidate interface unavailable")
        val resolved = NetworkInterface.getByName(name) ?: error("candidate interface unavailable")
        // Immutable uplink snapshot. The bridge cancels on context changes.
        listener.updateDefaultInterface(name, resolved.index, false, false)
    }

    override fun closeDefaultInterfaceMonitor(listener: InterfaceUpdateListener) = Unit

    override fun getInterfaces(): NetworkInterfaceIterator {
        val name = links.interfaceName ?: error("candidate interface unavailable")
        val resolved = NetworkInterface.getByName(name) ?: error("candidate interface unavailable")
        val value = space.pokrov.core.libbox.NetworkInterface().apply {
            setIndex(resolved.index)
            setName(name)
            setMTU(resolved.mtu)
            setAddresses(ProbeStringIterator(links.linkAddresses.map {
                AndroidPlatformRuntimeBridge.toLibboxPrefix(it.address, it.prefixLength.toShort())
            }))
        }
        return object : NetworkInterfaceIterator {
            private var pending = true
            override fun hasNext(): Boolean = pending
            override fun next(): space.pokrov.core.libbox.NetworkInterface {
                check(pending)
                pending = false
                return value
            }
        }
    }
}

private class ProbeStringIterator(private val values: List<String>) : StringIterator {
    private val iterator = values.iterator()
    override fun hasNext(): Boolean = iterator.hasNext()
    override fun next(): String = iterator.next()
    override fun len(): Int = values.size
}

/** Cancellable Android resolver on the captured uplink, with no live runtime health mutations. */
private class CapturedNetworkResolver(
    private val network: Network,
    private val dnsServers: List<InetAddress>,
    private val isCancelled: () -> Boolean,
) : LocalDNSTransport {
    private val inlineExecutor = Executor { it.run() }
    override fun raw(): Boolean = true

    override fun exchange(ctx: ExchangeContext, message: ByteArray) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            exchangeSocket(ctx, message)
            return
        }
        query(ctx, { answer: ByteArray -> ctx.rawSuccess(answer) }) { signal, callback ->
            DnsResolver.getInstance().rawQuery(network, message, AndroidResolverPolicy.QUERY_FLAGS,
                inlineExecutor, signal, callback)
        }
    }

    private fun exchangeSocket(ctx: ExchangeContext, message: ByteArray) {
        val server = dnsServers.firstOrNull() ?: error("candidate DNS unavailable")
        val cancelled = AtomicBoolean(false)
        val current = AtomicReference<Closeable?>()
        ctx.onCancel {
            cancelled.set(true)
            runCatching { current.get()?.close() }
        }
        fun own(socket: Closeable) {
            current.set(socket)
            if (cancelled.get() || isCancelled()) {
                socket.close()
                error("candidate DNS cancelled")
            }
        }
        try {
            val answer = DatagramSocket(null).use { socket ->
                own(socket)
                socket.bind(InetSocketAddress(0))
                network.bindSocket(socket)
                ParcelFileDescriptor.fromDatagramSocket(socket).use {
                    PokrovRuntimeVpnService.protectCandidateSocket(it.fd)
                }
                socket.connect(server, 53)
                socket.soTimeout = AndroidResolverPolicy.RESPONSE_WAIT_MILLIS.toInt()
                socket.send(DatagramPacket(message, message.size))
                val response = DatagramPacket(ByteArray(65_535), 65_535)
                socket.receive(response)
                response.data.copyOf(response.length)
            }
            // DNS truncation requires TCP on the same captured resolver/uplink.
            val complete = if (answer.size >= 4 && (answer[2].toInt() and 2) != 0) {
                Socket().use { socket ->
                    own(socket)
                    network.bindSocket(socket)
                    ParcelFileDescriptor.fromSocket(socket).use {
                        PokrovRuntimeVpnService.protectCandidateSocket(it.fd)
                    }
                    socket.soTimeout = AndroidResolverPolicy.RESPONSE_WAIT_MILLIS.toInt()
                    socket.connect(InetSocketAddress(server, 53), socket.soTimeout)
                    DataOutputStream(socket.getOutputStream()).apply {
                        writeShort(message.size)
                        write(message)
                        flush()
                    }
                    val input = DataInputStream(socket.getInputStream())
                    ByteArray(input.readUnsignedShort()).also(input::readFully)
                }
            } else answer
            check(complete.size >= 12 && message.size >= 2 && complete[0] == message[0] &&
                complete[1] == message[1] && (complete[2].toInt() and 0x80) != 0) { "candidate DNS invalid response" }
            if (!cancelled.get() && !isCancelled()) ctx.rawSuccess(complete)
        } finally {
            current.getAndSet(null)?.close()
        }
    }

    override fun lookup(ctx: ExchangeContext, network: String, domain: String) {
        // getAllByName before API29 cannot close its IO when cancelled.
        check(Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) { "candidate DNS unavailable" }
        query(ctx, { answer: Collection<InetAddress> ->
            ctx.success(answer.mapNotNull { it.hostAddress }.joinToString("\n"))
        }) { signal, callback ->
            val type = when {
                network.endsWith("4") -> DnsResolver.TYPE_A
                network.endsWith("6") -> DnsResolver.TYPE_AAAA
                else -> null
            }
            if (type == null) DnsResolver.getInstance().query(this.network, domain,
                AndroidResolverPolicy.QUERY_FLAGS, inlineExecutor, signal, callback)
            else DnsResolver.getInstance().query(this.network, domain, type,
                AndroidResolverPolicy.QUERY_FLAGS, inlineExecutor, signal, callback)
        }
    }

    private fun <T : Any> query(ctx: ExchangeContext, success: (T) -> Unit,
        start: (CancellationSignal, DnsResolver.Callback<T>) -> Unit) {
        val signal = CancellationSignal()
        val done = CountDownLatch(1)
        val settled = AtomicBoolean(false)
        ctx.onCancel {
            if (settled.compareAndSet(false, true)) {
                signal.cancel()
                done.countDown()
            }
        }
        if (settled.get() || isCancelled()) return
        try {
            start(signal, object : DnsResolver.Callback<T> {
                override fun onAnswer(answer: T, rcode: Int) {
                    if (settled.compareAndSet(false, true)) {
                        if (rcode == 0) success(answer) else ctx.errorCode(rcode)
                    }
                    done.countDown()
                }
                override fun onError(error: DnsResolver.DnsException) {
                    if (settled.compareAndSet(false, true)) ctx.errorCode(AndroidResolverPolicy.SERVFAIL_RCODE)
                    done.countDown()
                }
            })
            while (!done.await(10, TimeUnit.MILLISECONDS)) {
                if (isCancelled()) {
                    if (settled.compareAndSet(false, true)) {
                        signal.cancel()
                        break
                    }
                    // An answer already owns completion: join its ctx write.
                }
            }
        } finally {
            settled.set(true)
            signal.cancel()
        }
    }
}
