package space.pokrov.pokrov_android_shell

import java.io.DataInputStream
import java.net.InetAddress
import java.net.ServerSocket
import java.util.concurrent.CopyOnWriteArrayList
import java.util.concurrent.atomic.AtomicReference
import javax.net.ssl.SSLHandshakeException
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Test

class AndroidByeDpiServiceProofTest {
    @Test fun reportsSocksFailureWithoutPeerData() {
        val loopback = InetAddress.getByName("127.0.0.1")
        val peerFailure = AtomicReference<Throwable?>()
        val reasons = CopyOnWriteArrayList<String>()
        ServerSocket(0, 1, loopback).use { server ->
            lateinit var proof: AndroidByeDpiServiceProof
            val peer = Thread {
                try {
                    server.accept().use { socket ->
                        proof.reportClientFailure(-1, "uid_mismatch")
                        proof.reportClientFailure(socket.port, "uid_mismatch")
                        proof.reportClientFailure(socket.port, "uid_mismatch")
                        val input = DataInputStream(socket.getInputStream())
                        input.readFully(ByteArray(3))
                        socket.getOutputStream().write(byteArrayOf(5, 0))
                        input.readFully(ByteArray(10))
                        socket.getOutputStream().write(byteArrayOf(5, 8, 0, 1))
                    }
                } catch (failure: Throwable) {
                    peerFailure.set(failure)
                }
            }.apply { isDaemon = true; start() }
            proof = AndroidByeDpiServiceProof({ true }, { true }, { 3000 }) { reasons.add(it) }
            proof.use {
                assertFalse(it.run(server.localPort, "test.invalid", InetAddress.getByAddress(byteArrayOf(1, 2, 3, 4))))
            }
            peer.join(3000)
            assertFalse(peer.isAlive)
            assertNull(peerFailure.get())
        }
        assertEquals(listOf("proof_client=uid_mismatch",
            "proof_detail stage=socks_connect_reply family=ipv4 error=rejected socks_reply=8"), reasons)
        assertEquals("ssl_handshake", localDpiProofException(SSLHandshakeException("private peer data")))
    }
}
