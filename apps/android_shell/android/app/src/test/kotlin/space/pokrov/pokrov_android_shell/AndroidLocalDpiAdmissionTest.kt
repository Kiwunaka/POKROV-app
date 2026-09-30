package space.pokrov.pokrov_android_shell

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AndroidLocalDpiAdmissionTest {
    @Test fun capturesAllHoldersBeforeAnyProofAndWithdrawalKeepsCapturedIdentity() {
        val events = mutableListOf<String>()
        var prefix = "old"
        val holders = AndroidLocalDpiHolders({ true }, { tag -> events.add("read:$tag"); "$prefix-$tag" },
            { events.add("admit:$it"); true }, {
                events.add("withdraw:$it")
                if (it == "old-video-tag") throw IllegalStateException("closed native holder")
            })
        assertTrue(holders.capture(linkedMapOf("video" to "video-tag", "chat" to "chat-tag")))
        assertTrue(holders.publish("video") { events.add("proof"); true })
        prefix = "replacement"
        holders.close()
        assertEquals(listOf("read:video-tag", "read:chat-tag", "proof", "admit:old-video-tag",
            "withdraw:old-video-tag", "withdraw:old-chat-tag"), events)
        assertFalse(holders.publish("chat") { error("closed holder must not start proof") })
    }

    @Test fun cancellationOrProfileChangeDuringProofNeverAdmitsAndWithdrawsOnlyCapturedId() {
        var current = true
        val admitted = mutableListOf<String>()
        val withdrawn = mutableListOf<String>()
        val holders = AndroidLocalDpiHolders({ current }, { "captured" }, { admitted.add(it); true }, withdrawn::add)
        assertTrue(holders.capture(mapOf("video" to "tag")))
        assertFalse(holders.publish("video") { current = false; true })
        holders.close()
        assertTrue(admitted.isEmpty())
        assertEquals(listOf("captured"), withdrawn)
    }

    @Test fun signedServiceWithdrawalCannotBeReopenedByLateProof() {
        var admits = 0
        val holders = AndroidLocalDpiHolders({ true }, { "captured" }, { admits++; true }, {
            throw IllegalStateException("native withdrawal failed")
        })
        assertTrue(holders.capture(mapOf("video" to "tag")))
        assertFalse(holders.publish("video") { holders.withdrawService("video"); true })
        assertEquals(0, admits)
    }
}
