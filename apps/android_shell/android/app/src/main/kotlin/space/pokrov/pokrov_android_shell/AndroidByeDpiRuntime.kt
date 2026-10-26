package space.pokrov.pokrov_android_shell

import android.content.Context
import androidx.annotation.Keep
import android.net.LocalServerSocket
import android.net.LocalSocket
import android.net.LocalSocketAddress
import android.os.Build
import android.os.ParcelFileDescriptor
import android.os.Process
import android.system.ErrnoException
import android.system.Os
import android.system.OsConstants
import android.system.StructTimeval
import android.util.Log
import java.io.File
import java.io.EOFException
import java.io.IOException
import java.net.ConnectException
import java.net.Inet4Address
import java.net.InetAddress
import java.net.InetSocketAddress
import java.net.NoRouteToHostException
import java.net.Socket
import java.net.SocketException
import java.net.SocketTimeoutException
import java.security.SecureRandom
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicLong
import javax.net.ssl.SNIHostName
import javax.net.ssl.SSLException
import javax.net.ssl.SSLHandshakeException
import javax.net.ssl.SSLPeerUnverifiedException
import javax.net.ssl.SSLProtocolException
import javax.net.ssl.SSLSocket
import javax.net.ssl.SSLSocketFactory

internal enum class AndroidByeDpiStrategy { TLS_RECORD, DISORDER }

/** One embedded SOCKS loop and protect listener, owned by the existing VPN session. */
internal class AndroidByeDpiRuntime private constructor(
    context: Context,
    private val session: AndroidLifecycleTaskScope,
    private val ownsSession: () -> Boolean,
    private val protectSocket: (Int) -> Boolean,
    private val withdrawAdmission: (Boolean) -> Unit,
) : AutoCloseable {
    private val uid = Process.myUid()
    private val closed = AtomicBoolean(false)
    private val closeSettled = CountDownLatch(1)
    private val protectLock = Any()
    private val path = File(context.filesDir,
        "bd-${session.generation.toString(16)}-${SecureRandom().nextInt().toUInt().toString(16)}")
    private val bound = LocalSocket()
    private var server: LocalServerSocket? = null
    private var accepted: LocalSocket? = null
    private var nativeHandle = 0L
    private var listener: Thread? = null
    private var proof: AndroidByeDpiServiceProof? = null
    private var admitted = false

    /** A fresh proof admits only the caller's captured service/network/session. */
    val socksPort: Int
        get() = synchronized(protectLock) {
            check(admitted && isCurrent()) { "byedpi: service admission ended" }
            rawPort()
        }

    /** Only the native publisher uses this while Core holders are dormant. */
    val unprovenSocksPort: Int
        get() = synchronized(protectLock) { check(isCurrent()); rawPort() }

    fun proveService(host: String, address: InetAddress, remainingMillis: () -> Int,
        youtubeControl: Boolean): Boolean {
        val trace = youtubeControl && address is Inet4Address &&
            Log.isLoggable("POKROV-DPIProof", Log.DEBUG)
        val token = AtomicLong(0)
        val attempt = AndroidByeDpiServiceProof(::isCurrent, { socket ->
            synchronized(protectLock) {
                isCurrent() && ParcelFileDescriptor.fromSocket(socket).use {
                    protectSocket(it.fd)
                } && isCurrent()
            }
        }, remainingMillis, { port ->
            if (trace && isCurrent()) token.set(runCatching {
                nativeProofBegin(nativeHandle, port)
            }.getOrDefault(0))
        }, ::logLocalDpiDiagnostic)
        synchronized(protectLock) {
            if (!isCurrent()) return false
            proof = attempt
        }
        return try { attempt.run(rawPort(), SNIHostName(host).asciiName, address) }
        finally {
            attempt.close()
            if (trace && isCurrent()) runCatching {
                val stats = nativeProofFinish(nativeHandle, token.get())
                val seen = stats?.getOrNull(0) == 1L
                fun count(index: Int) = if (seen) stats!![index].toString() else "unknown"
                fun flag(index: Int) = when (stats?.getOrNull(index)) {
                    0L -> "false"
                    1L -> "true"
                    else -> "unknown"
                }
                if (isCurrent()) Log.d("POKROV-DPIProof",
                    "target_ipv4=${publicProofIpv4(address) ?: "unknown"} client_rx=${count(1)} " +
                    "upstream_tx=${count(2)} remote_rx=${count(3)} " +
                    "hello_sni_first_chunk=${flag(4)} tlsrec_applied=${flag(5)}")
            }
        }
    }

    fun markAdmitted(): Boolean = synchronized(protectLock) {
        isCurrent().also { if (it) admitted = true }
    }

    private fun rawPort(): Int = nativePort(nativeHandle).also {
        check(it != 0) { "byedpi: native runtime stopped" }
    }

    private fun isCurrent(): Boolean = !closed.get() && session.isActive() && ownsSession()

    // JNI checked a live TCP client socket held by this process; keep its
    // admission bound to the current VPN session as well.
    @Keep
    @Suppress("unused")
    private fun allowClient(clientPort: Int, ownership: Int): Boolean = synchronized(protectLock) {
        if (!isCurrent()) return@synchronized false
        if (ownership != 1) proof?.reportClientFailure(clientPort,
            if (ownership < 0) "fd_unavailable" else "not_in_process")
        ownership == 1 && isCurrent()
    }

    private fun listenForProtection() {
        try {
            while (isCurrent() && nativePort(nativeHandle) != 0) {
                val socket = try {
                    server!!.accept()
                } catch (failure: java.io.IOException) {
                    // SO_RCVTIMEO lets session cancellation settle an idle accept.
                    if (!isCurrent()) break
                    if ((failure.cause as? ErrnoException)?.errno != OsConstants.EAGAIN) throw failure
                    continue
                }
                synchronized(protectLock) { accepted = socket }
                socket.use {
                    var ownerPeer = false
                    try {
                        it.soTimeout = 1000
                        if (it.peerCredentials.uid != uid || !isCurrent()) return@use
                        ownerPeer = true
                        val marker = it.inputStream.read()
                        val descriptors = it.ancillaryFileDescriptors ?: emptyArray()
                        try {
                            if (marker != '1'.code || descriptors.size != 1) {
                                proof?.reportUplinkProtection("invalid_request")
                                return@use
                            }
                            ParcelFileDescriptor.dup(descriptors[0]).use { descriptor ->
                                synchronized(protectLock) {
                                    acknowledgeByeDpiProtection(
                                        it.peerCredentials.uid, uid, ::isCurrent,
                                        { protectSocket(descriptor.fd).also { protected ->
                                            if (!protected) proof?.reportUplinkProtection("refused")
                                        } },
                                        { it.outputStream.write('1'.code); proof?.reportUplinkProtection("ok") },
                                    )
                                }
                            }
                        } finally {
                            descriptors.forEach { descriptor -> Os.close(descriptor) }
                        }
                    } catch (_: Exception) {
                        if (ownerPeer) proof?.reportUplinkProtection("exception")
                        // Upstream treats any byte as success. On denial, malformed
                        // FD transfer, or revoked session, close without an ACK.
                    }
                }
                synchronized(protectLock) { accepted = null }
            }
        } finally {
            close()
        }
    }

    override fun close() {
        val worker = listener
        if (!closed.compareAndSet(false, true)) {
            // The listener's finally must not wait on the caller joining it.
            if (worker !== Thread.currentThread()) {
                var interrupted = false
                while (true) {
                    try { closeSettled.await(); break }
                    catch (_: InterruptedException) { interrupted = true }
                }
                if (interrupted) Thread.currentThread().interrupt()
            }
            return
        }
        try {
            // The callback carries the captured identity. Its owner compares it
            // with the published route before withdrawing new-flow admission.
            synchronized(protectLock) { admitted = false }
            val withdrawal = runCatching {
                withdrawAdmission(nativePort(nativeHandle) == 0)
            }
            proof?.close()
            synchronized(protectLock) { runCatching { accepted?.close() } }
            if (nativeHandle != 0L) nativeStop(nativeHandle)
            if (worker != null) joinByeDpiWorker(worker)
            server?.close()
            bound.close()
            // This path belongs to this instance and is only its ephemeral Unix socket.
            path.delete()
            withdrawal.getOrThrow()
        } finally {
            closeSettled.countDown()
        }
    }

    private external fun nativeStart(protectPath: String, strategy: Int, requestedPort: Int): Long
    private external fun nativePort(handle: Long): Int
    private external fun nativeStop(handle: Long)
    private external fun nativeProofBegin(handle: Long, port: Int): Long
    private external fun nativeProofFinish(handle: Long, token: Long): LongArray?

    companion object {
        private var lastStrategy: Pair<String, AndroidByeDpiStrategy>? = null

        @Synchronized fun strategyOrder(network: String): List<AndroidByeDpiStrategy> {
            if (lastStrategy?.first != network) lastStrategy = null
            return AndroidByeDpiStrategy.entries.sortedBy { if (it == lastStrategy?.second) 0 else 1 }
        }

        @Synchronized fun rememberStrategy(network: String, strategy: AndroidByeDpiStrategy) {
            lastStrategy = network to strategy
        }

        /** Binds a loopback endpoint; it grants no Core route admission. */
        fun startUnproven(
            context: Context,
            session: AndroidLifecycleTaskScope,
            ownsSession: () -> Boolean,
            protectSocket: (Int) -> Boolean,
            strategy: AndroidByeDpiStrategy,
            requestedPort: Int = 0,
            withdrawAdmission: (Boolean) -> Unit,
        ): AndroidByeDpiRuntime {
            check(Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                "byedpi: Android 10 is required"
            }
            check(session.isActive() && ownsSession()) { "byedpi: inactive VPN session" }
            System.loadLibrary("pokrov_byedpi")
            val runtime = AndroidByeDpiRuntime(context, session, ownsSession, protectSocket, withdrawAdmission)
            try {
                check(runtime.path.absolutePath.toByteArray(Charsets.UTF_8).size < 108) {
                    "byedpi: protect socket path exceeds Unix socket limit"
                }
                runtime.bound.bind(LocalSocketAddress(runtime.path.absolutePath,
                    LocalSocketAddress.Namespace.FILESYSTEM))
                Os.setsockoptTimeval(runtime.bound.fileDescriptor, OsConstants.SOL_SOCKET,
                    OsConstants.SO_RCVTIMEO, StructTimeval.fromMillis(1000))
                runtime.server = LocalServerSocket(runtime.bound.fileDescriptor)
                runtime.nativeHandle = runtime.nativeStart(runtime.path.absolutePath, strategy.ordinal, requestedPort)
                logLocalDpiDiagnostic(if (strategy == AndroidByeDpiStrategy.TLS_RECORD)
                    "strategy=tls_record" else "strategy=disorder")
                runtime.listener = Thread(runtime::listenForProtection, "pokrov-byedpi-protect").apply {
                    isDaemon = true
                    start()
                }
                session.onCancel(runtime::close)
                check(runtime.isCurrent() && runtime.rawPort() != 0) { "byedpi: VPN session superseded" }
                return runtime
            } catch (failure: Throwable) {
                runtime.close()
                throw failure
            }
        }
    }
}

private fun publicProofIpv4(address: InetAddress): String? {
    if (address !is Inet4Address) return null
    val bytes = address.address.map { it.toInt() and 255 }
    val (a, b, c) = bytes
    if (a == 0 || a == 10 || a == 127 || a >= 224 ||
        a == 100 && b in 64..127 || a == 169 && b == 254 ||
        a == 172 && b in 16..31 || a == 192 && (b == 0 || b == 168 || b == 88 && c == 99) ||
        a == 198 && (b in 18..19 || b == 51 && c == 100) || a == 203 && b == 0 && c == 113) return null
    return address.hostAddress
}

/** One cancellable, bounded SOCKS/TLS/HEAD exchange; no Android or JNI calls. */
internal class AndroidByeDpiServiceProof(
    private val isCurrent: () -> Boolean,
    private val protectSocket: (Socket) -> Boolean,
    private val remainingMillis: () -> Int,
    private val onBound: (Int) -> Unit = {},
    private val diagnostic: (String) -> Unit,
) : AutoCloseable {
    private val lock = Any()
    private var closed = false
    private var raw: Socket? = null
    private var tls: SSLSocket? = null
    private var worker: Thread? = null
    private val settled = CountDownLatch(1)
    private val reported = AtomicBoolean(false)
    private val clientReported = AtomicBoolean(false)
    private val uplinkReported = AtomicBoolean(false)
    @Volatile private var passed = false
    @Volatile private var stage = "start"
    private var family = "unknown"

    fun run(socksPort: Int, host: String, address: InetAddress): Boolean {
        family = if (address.address.size == 4) "ipv4" else "ipv6"
        val waitMillis = synchronized(lock) {
            check(worker == null) { "byedpi: proof already started" }
            if (closed || !isCurrent() || remainingMillis() <= 0) {
                report("inactive_or_deadline")
                return false
            }
            val limit = remainingMillis()
            worker = Thread({
                try {
                    exchange(socksPort, host, address)
                    passed = current()
                    if (!passed) report("inactive")
                } catch (failure: Exception) {
                    // A failed handshake/status never admits a service or retries ciphertext.
                    report(localDpiProofException(failure))
                } finally {
                    closeSockets()
                    settled.countDown()
                }
            }, "pokrov-byedpi-proof").apply { isDaemon = true; start() }
            limit
        }
        try {
            // SO_TIMEOUT bounds individual reads; this deadline bounds the entire
            // exchange, including a peer dripping TLS handshake records.
            if (!settled.await(waitMillis.toLong().coerceAtLeast(0), TimeUnit.MILLISECONDS)) {
                report("deadline")
                close()
                return false
            }
        } catch (_: InterruptedException) {
            report("interrupted")
            close()
            Thread.currentThread().interrupt()
            return false
        }
        return passed && current()
    }

    private fun current(): Boolean = synchronized(lock) { !closed && isCurrent() }
    fun reportClientFailure(port: Int, error: String) {
        val isProofClient = synchronized(lock) { !closed && raw?.localPort == port }
        if (isProofClient && clientReported.compareAndSet(false, true)) diagnostic("proof_client=$error")
    }

    fun reportUplinkProtection(result: String) {
        if ((stage == "socks_connect_write" || stage == "socks_connect_reply") && current() &&
            uplinkReported.compareAndSet(false, true)) diagnostic("proof_uplink=$result")
    }

    private fun report(error: String, detail: String = "") {
        if (reported.compareAndSet(false, true)) {
            diagnostic("proof_detail stage=$stage family=$family error=$error$detail")
        }
    }

    private fun budget(): Int {
        if (!current()) throw IOException("byedpi: proof superseded")
        return remainingMillis().also { if (it <= 0) throw IOException("byedpi: proof deadline") }
    }

    private fun exchange(port: Int, host: String, address: InetAddress) {
        val socket = Socket()
        synchronized(lock) {
            if (!current()) { socket.close(); throw IOException("byedpi: proof superseded") }
            raw = socket
        }
        // Create the FD before protecting the same loopback transport used by
        // Core. An included host UID must not send this proof back into its TUN.
        stage = "socket_bind"
        socket.bind(InetSocketAddress("127.0.0.1", 0))
        onBound(socket.localPort)
        stage = "protect"
        if (!protectSocket(socket)) {
            report("refused")
            throw IOException("byedpi: proof protection refused")
        }
        stage = "loopback_connect"
        socket.connect(InetSocketAddress("127.0.0.1", port), budget())
        socket.soTimeout = budget()
        val output = socket.getOutputStream()
        stage = "socks_auth_write"
        output.write(byteArrayOf(5, 1, 0))
        stage = "socks_auth_reply"
        if (!readExactly(socket, 2).contentEquals(byteArrayOf(5, 0))) {
            report("invalid_reply")
            throw IOException("byedpi: SOCKS auth")
        }
        val bytes = address.address
        budget()
        stage = "socks_connect_write"
        output.write(byteArrayOf(5, 1, 0, (if (bytes.size == 4) 1 else 4).toByte()) +
            bytes + byteArrayOf(1, 0xbb.toByte()))
        socket.soTimeout = budget()
        stage = "socks_connect_reply"
        val reply = readExactly(socket, 4)
        if (reply[0] != 5.toByte() || reply[1] != 0.toByte() || reply[2] != 0.toByte()) {
            if (reply[0] == 5.toByte() && reply[2] == 0.toByte()) {
                report("rejected", " socks_reply=${reply[1].toInt() and 255}")
            } else {
                report("invalid_reply")
            }
            throw IOException("byedpi: SOCKS connect")
        }
        readExactly(socket, when (reply[3].toInt()) {
            1 -> 4
            4 -> 16
            3 -> readExactly(socket, 1)[0].toInt() and 255
            else -> { report("invalid_address_type"); throw IOException("byedpi: SOCKS address") }
        } + 2)
        budget()
        stage = "tls_setup"
        val secure = (SSLSocketFactory.getDefault() as SSLSocketFactory)
            .createSocket(socket, host, 443, true) as SSLSocket
        synchronized(lock) {
            if (!current()) { secure.close(); throw IOException("byedpi: proof superseded") }
            tls = secure
        }
        secure.sslParameters = secure.sslParameters.apply {
            endpointIdentificationAlgorithm = "HTTPS"
            serverNames = listOf(SNIHostName(host))
        }
        secure.soTimeout = budget()
        stage = "tls_handshake"
        secure.startHandshake()
        secure.soTimeout = budget()
        stage = "http_write"
        secure.outputStream.write("HEAD / HTTP/1.1\r\nHost: $host\r\nConnection: close\r\n\r\n"
            .toByteArray(Charsets.US_ASCII))
        val response = secure.inputStream
        fun line(): String {
            val text = StringBuilder()
            while (text.length < 1024) {
                secure.soTimeout = budget()
                val value = response.read()
                if (value < 0) throw EOFException()
                if (value == 10) return text.toString().removeSuffix("\r")
                text.append(value.toChar())
            }
            throw IOException("byedpi: HTTP header limit")
        }
        stage = "http_status"
        val status = line()
        if (!Regex("HTTP/1\\.[01] 2[0-9]{2}(?: .*)?").matches(status)) {
            val code = Regex("HTTP/1\\.[01] ([0-9]{3})(?: .*)?").matchEntire(status)?.groupValues?.get(1)
            if (code == null) report("invalid_status") else report("rejected", " http_status=$code")
            throw IOException("byedpi: HTTP status")
        }
        stage = "http_headers"
        var headerBytes = status.length
        while (true) {
            val header = line()
            headerBytes += header.length + 2
            if (headerBytes > 8192) throw IOException("byedpi: HTTP header limit")
            if (header.isEmpty()) break
        }
        // HEAD ends here: no redirects, body, content capture or downloads.
        budget()
    }

    private fun readExactly(socket: Socket, size: Int): ByteArray = ByteArray(size).also { bytes ->
        val input = socket.getInputStream()
        var offset = 0
        while (offset < bytes.size) {
            socket.soTimeout = budget()
            val count = input.read(bytes, offset, bytes.size - offset)
            if (count < 0) throw EOFException()
            offset += count
        }
    }

    private fun closeSockets() {
        val sockets = synchronized(lock) { (raw to tls).also { raw = null; tls = null } }
        // Close the transport first, so SSLSocket.close cannot wait on TLS shutdown.
        runCatching { sockets.first?.close() }
        runCatching { sockets.second?.close() }
    }

    override fun close() {
        val thread = synchronized(lock) { closed = true; worker }
        closeSockets()
        if (thread != null) joinByeDpiWorker(thread)
    }
}

// Do not report exception messages, hosts, addresses, or any other peer data.
internal fun localDpiProofException(failure: Exception): String = when (failure) {
    is SSLHandshakeException -> "ssl_handshake"
    is SSLPeerUnverifiedException -> "ssl_peer_unverified"
    is SSLProtocolException -> "ssl_protocol"
    is SSLException -> "ssl"
    is SocketTimeoutException -> "socket_timeout"
    is ConnectException -> "connect"
    is NoRouteToHostException -> "no_route"
    is SocketException -> "socket"
    is EOFException -> "eof"
    is IOException -> "io"
    is SecurityException -> "security"
    is IllegalArgumentException -> "illegal_argument"
    else -> "other"
}

// Scope cancellation interrupts its JVM worker before running close hooks.
// Preserve that signal after sockets and both owned workers have settled.
private fun joinByeDpiWorker(worker: Thread) {
    if (worker === Thread.currentThread()) return
    var interrupted = Thread.interrupted()
    while (true) {
        try { worker.join(); break }
        catch (_: InterruptedException) { interrupted = true }
    }
    if (interrupted) Thread.currentThread().interrupt()
}

internal fun acknowledgeByeDpiProtection(
    peerUid: Int,
    ownerUid: Int,
    isCurrent: () -> Boolean,
    protect: () -> Boolean,
    acknowledge: () -> Unit,
) {
    if (peerUid != ownerUid || !isCurrent()) return
    if (!protect() || !isCurrent()) return
    acknowledge()
}
