package space.pokrov.pokrov_android_shell

import android.content.Context
import android.net.ConnectivityManager
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
import java.io.File
import java.io.EOFException
import java.io.IOException
import java.net.InetAddress
import java.net.InetSocketAddress
import java.net.Socket
import java.security.SecureRandom
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean
import javax.net.ssl.SNIHostName
import javax.net.ssl.SSLSocket
import javax.net.ssl.SSLSocketFactory

internal enum class AndroidByeDpiStrategy { SPLIT, DISORDER }

/** One embedded SOCKS loop and protect listener, owned by the existing VPN session. */
internal class AndroidByeDpiRuntime private constructor(
    context: Context,
    private val session: AndroidLifecycleTaskScope,
    private val ownsSession: () -> Boolean,
    private val protectSocket: (Int) -> Boolean,
    private val withdrawAdmission: (Boolean) -> Unit,
) : AutoCloseable {
    private val network = context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
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

    fun proveService(host: String, address: InetAddress, remainingMillis: () -> Int): Boolean {
        val attempt = AndroidByeDpiServiceProof(::isCurrent, remainingMillis)
        synchronized(protectLock) {
            if (!isCurrent()) return false
            proof = attempt
        }
        return try { attempt.run(rawPort(), SNIHostName(host).asciiName, address) }
        finally { attempt.close() }
    }

    fun markAdmitted(): Boolean = synchronized(protectLock) {
        isCurrent().also { if (it) admitted = true }
    }

    private fun rawPort(): Int = nativePort(nativeHandle).also {
        check(it != 0) { "byedpi: native runtime stopped" }
    }

    private fun isCurrent(): Boolean = !closed.get() && session.isActive() && ownsSession()

    // Called by JNI before a SOCKS client can create a protected uplink. A
    // loopback listener alone would otherwise be a Direct proxy for other apps.
    @Suppress("unused")
    private fun allowClient(clientPort: Int, serverPort: Int): Boolean = synchronized(protectLock) {
        isCurrent() && network.getConnectionOwnerUid(
            OsConstants.IPPROTO_TCP,
            InetSocketAddress("127.0.0.1", clientPort),
            InetSocketAddress("127.0.0.1", serverPort),
        ) == uid && isCurrent()
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
                    try {
                        it.soTimeout = 1000
                        if (it.peerCredentials.uid != uid || !isCurrent()) return@use
                        val marker = it.inputStream.read()
                        val descriptors = it.ancillaryFileDescriptors ?: emptyArray()
                        try {
                            if (marker != '1'.code || descriptors.size != 1) return@use
                            ParcelFileDescriptor.dup(descriptors[0]).use { descriptor ->
                                synchronized(protectLock) {
                                    acknowledgeByeDpiProtection(
                                        it.peerCredentials.uid, uid, ::isCurrent,
                                        { protectSocket(descriptor.fd) },
                                        { it.outputStream.write('1'.code) },
                                    )
                                }
                            }
                        } finally {
                            descriptors.forEach { descriptor -> Os.close(descriptor) }
                        }
                    } catch (_: Exception) {
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
                "byedpi: Android 10 connection-owner admission is required"
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

/** One cancellable, bounded SOCKS/TLS/HEAD exchange; no Android or JNI calls. */
internal class AndroidByeDpiServiceProof(
    private val isCurrent: () -> Boolean,
    private val remainingMillis: () -> Int,
) : AutoCloseable {
    private val lock = Any()
    private var closed = false
    private var raw: Socket? = null
    private var tls: SSLSocket? = null
    private var worker: Thread? = null
    private val settled = CountDownLatch(1)
    @Volatile private var passed = false

    fun run(socksPort: Int, host: String, address: InetAddress): Boolean {
        val waitMillis = synchronized(lock) {
            check(worker == null) { "byedpi: proof already started" }
            if (closed || !isCurrent() || remainingMillis() <= 0) return false
            val limit = remainingMillis()
            worker = Thread({
                try {
                    exchange(socksPort, host, address)
                    passed = current()
                } catch (_: Exception) {
                    // A failed handshake/status never admits a service or retries ciphertext.
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
                close()
                return false
            }
        } catch (_: InterruptedException) {
            close()
            Thread.currentThread().interrupt()
            return false
        }
        return passed && current()
    }

    private fun current(): Boolean = synchronized(lock) { !closed && isCurrent() }
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
        socket.connect(InetSocketAddress("127.0.0.1", port), budget())
        socket.soTimeout = budget()
        val output = socket.getOutputStream()
        output.write(byteArrayOf(5, 1, 0))
        if (!readExactly(socket, 2).contentEquals(byteArrayOf(5, 0))) throw IOException("byedpi: SOCKS auth")
        val bytes = address.address
        budget()
        output.write(byteArrayOf(5, 1, 0, (if (bytes.size == 4) 1 else 4).toByte()) +
            bytes + byteArrayOf(1, 0xbb.toByte()))
        socket.soTimeout = budget()
        val reply = readExactly(socket, 4)
        if (reply[0] != 5.toByte() || reply[1] != 0.toByte() || reply[2] != 0.toByte()) {
            throw IOException("byedpi: SOCKS connect")
        }
        readExactly(socket, when (reply[3].toInt()) {
            1 -> 4
            4 -> 16
            3 -> readExactly(socket, 1)[0].toInt() and 255
            else -> throw IOException("byedpi: SOCKS address")
        } + 2)
        budget()
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
        secure.startHandshake()
        secure.soTimeout = budget()
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
        val status = line()
        if (!Regex("HTTP/1\\.[01] 2[0-9]{2}(?: .*)?").matches(status)) throw IOException("byedpi: HTTP status")
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
