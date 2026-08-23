package space.pokrov.pokrov_android_shell

import java.io.File
import java.nio.file.Files
import java.net.URI
import java.security.MessageDigest
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Assert.assertEquals
import org.junit.Test

class AndroidClientUpdateInstallerTest {
    @Test
    fun acceptsOnlyCanonicalGitHubApkMetadata() {
        val valid = AndroidClientUpdateInstaller.validateRequest(
            "https://github.com/Kiwunaka/pokrov/releases/download/v1.0.8/pokrov-android-arm64-v8a.apk",
            "a".repeat(64),
            99_117_667L,
        )
        assertNotNull(valid)

        assertNull(
            AndroidClientUpdateInstaller.validateRequest(
                "https://github.com.evil.example/Kiwunaka/pokrov/releases/download/v1/pokrov.apk",
                "a".repeat(64),
                10L,
            ),
        )
        assertNull(
            AndroidClientUpdateInstaller.validateRequest(
                "https://github.com/Kiwunaka/pokrov/releases/download/v1/not-an-apk.zip",
                "a".repeat(64),
                10L,
            ),
        )
        assertNull(
            AndroidClientUpdateInstaller.validateRequest(
                "https://github.com/Kiwunaka/pokrov/releases/download/v1/pokrov.apk?token=unsafe",
                "a".repeat(64),
                10L,
            ),
        )
        assertNull(
            AndroidClientUpdateInstaller.validateRequest(
                "https://github.com/Kiwunaka/pokrov/releases/download/v1/${"a".repeat(2_048)}.apk",
                "a".repeat(64),
                10L,
            ),
        )
        assertNull(
            AndroidClientUpdateInstaller.validateRequest(
                valid!!.url,
                valid.sha256,
                AndroidClientUpdateRequestPolicy.MAX_APK_BYTES + 1L,
            ),
        )
        assertNull(
            AndroidClientUpdateInstaller.validateRequest(
                valid.url,
                valid.sha256,
                valid.size,
                version = "1.${"2".repeat(65)}.0",
            ),
        )
    }

    @Test
    fun acceptsOnlyGitHubOwnedHttpsRedirects() {
        assertTrue(
            AndroidClientUpdateInstaller.isAllowedRedirectUri(
                URI("https://release-assets.githubusercontent.com/github-production-release-asset/1/file?token=ok"),
            ),
        )
        assertTrue(
            AndroidClientUpdateInstaller.isAllowedRedirectUri(
                URI("https://github.com/Kiwunaka/pokrov/releases/download/v1/pokrov.apk"),
            ),
        )
        assertFalse(
            AndroidClientUpdateInstaller.isAllowedRedirectUri(
                URI("https://githubusercontent.com.evil.example/file.apk"),
            ),
        )
        assertFalse(
            AndroidClientUpdateInstaller.isAllowedRedirectUri(
                URI("http://release-assets.githubusercontent.com/file.apk"),
            ),
        )
    }

    @Test
    fun verifiesExactApkSizeAndSha256() {
        val directory = Files.createTempDirectory("pokrov-update-test-").toFile()
        try {
            val file = File(directory, "update.apk")
            val bytes = "verified-pokrov-update".toByteArray()
            file.writeBytes(bytes)
            val sha = MessageDigest.getInstance("SHA-256")
                .digest(bytes)
                .joinToString("") { "%02x".format(it.toInt() and 0xff) }
            val request = AndroidClientUpdateRequest(
                url = "https://github.com/Kiwunaka/pokrov/releases/download/v1/pokrov.apk",
                sha256 = sha,
                size = bytes.size.toLong(),
            )

            assertTrue(AndroidClientUpdateInstaller.verifyFile(file, request))
            assertFalse(
                AndroidClientUpdateInstaller.verifyFile(
                    file,
                    request.copy(sha256 = "0".repeat(64)),
                ),
            )
            assertFalse(
                AndroidClientUpdateInstaller.verifyFile(
                    file,
                    request.copy(size = request.size + 1),
                ),
            )
        } finally {
            directory.deleteRecursively()
        }
    }

    @Test
    fun exposesBoundedDownloadProgressWithoutReleaseMaterial() {
        val payload = AndroidClientUpdateProgress(
            phase = "downloading",
            downloadedBytes = 512L,
            totalBytes = 1_024L,
        ).toMap()

        assertEquals("downloading", payload["phase"])
        assertEquals(512L, payload["downloaded_bytes"])
        assertEquals(1_024L, payload["total_bytes"])
        assertFalse(payload.containsKey("url"))
        assertFalse(payload.containsKey("sha256"))
    }

    @Test
    fun verifierStopsBeforeReadingWhenParentScopeIsCancelled() {
        val directory = Files.createTempDirectory("pokrov-update-cancel-test-").toFile()
        try {
            val file = File(directory, "update.apk").apply { writeText("cancelled") }
            val request = AndroidClientUpdateRequest(
                url = "https://github.com/Kiwunaka/pokrov/releases/download/v1/pokrov.apk",
                sha256 = "0".repeat(64),
                size = file.length(),
            )
            var cancelled = false

            try {
                AndroidClientUpdateInstaller.verifyFile(
                    file = file,
                    request = request,
                    shouldContinue = { false },
                )
            } catch (error: IllegalStateException) {
                cancelled = true
                assertEquals("update_cancelled", error.message)
            }

            assertTrue(cancelled)
        } finally {
            directory.deleteRecursively()
        }
    }
}
