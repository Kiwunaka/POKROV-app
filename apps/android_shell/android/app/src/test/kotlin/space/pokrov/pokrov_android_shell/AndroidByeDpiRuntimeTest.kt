package space.pokrov.pokrov_android_shell

import java.io.EOFException
import java.io.InputStream
import java.net.InetAddress
import java.net.ServerSocket
import java.net.Socket
import java.net.SocketException
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicReference
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AndroidByeDpiRuntimeTest {
    @Test
    fun foreignUidNeverReceivesProtectionOrAcknowledgement() {
        var protects = 0
        var acknowledgements = 0
        acknowledgeByeDpiProtection(43, 42, { true }, { protects++; true }, { acknowledgements++ })
        assertEquals(0, protects)
        assertEquals(0, acknowledgements)
    }

    @Test
    fun refusedProtectionClosesWithoutAcknowledgement() {
        var protects = 0
        var acknowledgements = 0
        acknowledgeByeDpiProtection(42, 42, { true }, { protects++; false }, { acknowledgements++ })
        assertEquals(1, protects)
        assertEquals(0, acknowledgements)
    }

    @Test
    fun sessionSupersededDuringProtectionReceivesNoAcknowledgement() {
        var current = true
        var protects = 0
        var acknowledgements = 0
        acknowledgeByeDpiProtection(42, 42, { current }, {
            protects++
            current = false
            true
        }, { acknowledgements++ })
        assertEquals(1, protects)
        assertEquals(0, acknowledgements)
    }

    @Test
    fun currentOwnUidReceivesAcknowledgementOnlyAfterSuccessfulProtection() {
        var protects = 0
        var acknowledgements = 0
        acknowledgeByeDpiProtection(42, 42, { true }, { protects++; true }, {
            assertEquals(1, protects)
            acknowledgements++
        })
        assertEquals(1, protects)
        assertEquals(1, acknowledgements)
    }

    @Test(timeout = 10_000)
    fun cancellationClosesPendingTlsThroughSocksAndJoinsItsWorker() {
        val scope = AndroidLifecycleTaskScope(71L, "byedpi-cancel-test", 1)
        val proof = AndroidByeDpiServiceProof(scope::isActive) { 30_000 }
        scope.onCancel(proof::close)
        val tlsStarted = CountDownLatch(1)
        val resultReady = CountDownLatch(1)
        val result = AtomicReference<Boolean>()
        val peerFailure = AtomicReference<Throwable>()
        ServerSocket(0, 1, InetAddress.getByName("127.0.0.1")).use { server ->
            server.soTimeout = 2000
            val peer = Thread {
                try {
                    server.accept().use { socket ->
                        socket.soTimeout = 3000
                        receiveSocksConnect(socket)
                        socket.getOutputStream().write(SOCKS_SUCCESS)
                        val input = socket.getInputStream()
                        val header = readExactly(input, 5)
                        assertEquals(22, header[0].toInt()) // TLS handshake after SOCKS CONNECT.
                        readExactly(input, ((header[3].toInt() and 255) shl 8) +
                            (header[4].toInt() and 255))
                        tlsStarted.countDown()
                        while (input.read() != -1) { /* Wait for transport closure, not a TLS reply. */ }
                    }
                } catch (failure: Throwable) { peerFailure.set(failure) }
            }.apply { isDaemon = true; start() }
            try {
                assertTrue(scope.execute {
                    result.set(proof.run(server.localPort, "service.example", CONTROL_ADDRESS))
                    resultReady.countDown()
                })
                assertTrue(tlsStarted.await(2, TimeUnit.SECONDS))
                scope.close()
                assertTrue(scope.awaitClosed(2000))
                assertTrue(resultReady.await(2, TimeUnit.SECONDS))
                peer.join(2000)
                assertFalse(peer.isAlive)
                peerFailure.get()?.let { throw it }
                assertEquals(false, result.get())
            } finally {
                scope.close()
                proof.close()
            }
        }
    }

    @Test(timeout = 10_000)
    fun changedNetworkAfterSocksConnectRejectsReplyBeforeTlsOrAdmission() {
        val network = AtomicReference("network-a")
        val scope = AndroidLifecycleTaskScope(72L, "byedpi-network-test", 1)
        val proof = AndroidByeDpiServiceProof({ scope.isActive() && network.get() == "network-a" }) { 30_000 }
        scope.onCancel(proof::close)
        val connected = CountDownLatch(1)
        val releaseReply = CountDownLatch(1)
        val resultReady = CountDownLatch(1)
        val result = AtomicReference<Boolean>()
        val peerFailure = AtomicReference<Throwable>()
        ServerSocket(0, 1, InetAddress.getByName("127.0.0.1")).use { server ->
            server.soTimeout = 2000
            val peer = Thread {
                try {
                    server.accept().use { socket ->
                        socket.soTimeout = 3000
                        receiveSocksConnect(socket)
                        connected.countDown()
                        assertTrue(releaseReply.await(2, TimeUnit.SECONDS))
                        try {
                            socket.getOutputStream().write(SOCKS_SUCCESS)
                            assertEquals(-1, socket.getInputStream().read())
                        } catch (_: SocketException) {
                            // The client may close with the now-unread reply still pending.
                        }
                    }
                } catch (failure: Throwable) { peerFailure.set(failure) }
            }.apply { isDaemon = true; start() }
            try {
                assertTrue(scope.execute {
                    result.set(proof.run(server.localPort, "service.example", CONTROL_ADDRESS))
                    resultReady.countDown()
                })
                assertTrue(connected.await(2, TimeUnit.SECONDS))
                network.set("network-b")
                releaseReply.countDown()
                assertTrue(resultReady.await(2, TimeUnit.SECONDS))
                assertEquals(false, result.get())
                peer.join(2000)
                assertFalse(peer.isAlive)
                peerFailure.get()?.let { throw it }
            } finally {
                releaseReply.countDown()
                scope.close()
                proof.close()
                assertTrue(scope.awaitClosed(2000))
            }
        }
    }

    private fun receiveSocksConnect(socket: Socket) {
        val input = socket.getInputStream()
        assertArrayEquals(byteArrayOf(5, 1, 0), readExactly(input, 3))
        socket.getOutputStream().write(byteArrayOf(5, 0))
        assertArrayEquals(byteArrayOf(5, 1, 0, 1, 127, 0, 0, 2, 1, 0xbb.toByte()), readExactly(input, 10))
    }

    private fun readExactly(input: InputStream, count: Int): ByteArray = ByteArray(count).also { bytes ->
        var offset = 0
        while (offset < count) {
            val read = input.read(bytes, offset, count - offset)
            if (read < 0) throw EOFException()
            offset += read
        }
    }

    private companion object {
        val CONTROL_ADDRESS: InetAddress = InetAddress.getByAddress(byteArrayOf(127, 0, 0, 2))
        val SOCKS_SUCCESS = byteArrayOf(5, 0, 0, 1, 127, 0, 0, 1, 0, 0)
    }
}
