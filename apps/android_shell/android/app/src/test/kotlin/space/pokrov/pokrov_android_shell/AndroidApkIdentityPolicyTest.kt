package space.pokrov.pokrov_android_shell

import java.io.File
import java.nio.file.Files
import java.util.Properties
import java.util.zip.ZipEntry
import java.util.zip.ZipOutputStream
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class AndroidApkIdentityPolicyTest {
    @Test
    fun sanitizedFixtureAcceptsExactPackageVersionSignerSdkAndAbi() {
        val fixture = fixtureIdentity()

        assertNull(
            AndroidApkIdentityPolicy.rejection(
                identity = fixture,
                request = request(),
                expectedPackageName = PACKAGE_NAME,
                installedVersionCode = 119L,
                installedCurrentSignerSha256 = setOf(SIGNER_A),
                installedSigningLineageSha256 = setOf(SIGNER_A),
                deviceSdk = 35,
                deviceAbis = setOf("arm64-v8a"),
                authorizedSignerSha256 = setOf(SIGNER_A),
            ),
        )
    }

    @Test
    fun platformVerifiedRotationLineageAcceptsAnAuthorizedAncestor() {
        val rotated = fixtureIdentity().copy(
            currentSignerSha256 = setOf(SIGNER_C),
            signingLineageSha256 = setOf(SIGNER_A, SIGNER_C),
        )

        assertNull(
            AndroidApkIdentityPolicy.rejection(
                identity = rotated,
                request = request(),
                expectedPackageName = PACKAGE_NAME,
                installedVersionCode = 119L,
                installedCurrentSignerSha256 = setOf(SIGNER_A),
                installedSigningLineageSha256 = setOf(SIGNER_A),
                deviceSdk = 35,
                deviceAbis = setOf("arm64-v8a"),
                authorizedSignerSha256 = setOf(SIGNER_A),
            ),
        )
    }

    @Test
    fun everyIdentityMismatchFailsClosedBeforeInstallerHandoff() {
        val fixture = fixtureIdentity()
        fun rejection(
            identity: AndroidApkIdentity = fixture,
            request: AndroidClientUpdateRequest = request(),
            installedVersionCode: Long = 119L,
            installedCurrentSigners: Set<String> = setOf(SIGNER_A),
            installedLineage: Set<String> = setOf(SIGNER_A),
            deviceSdk: Int = 35,
            deviceAbis: Set<String> = setOf("arm64-v8a"),
            signers: Set<String> = setOf(SIGNER_A),
        ) = AndroidApkIdentityPolicy.rejection(
            identity = identity,
            request = request,
            expectedPackageName = PACKAGE_NAME,
            installedVersionCode = installedVersionCode,
            installedCurrentSignerSha256 = installedCurrentSigners,
            installedSigningLineageSha256 = installedLineage,
            deviceSdk = deviceSdk,
            deviceAbis = deviceAbis,
            authorizedSignerSha256 = signers,
        )

        assertEquals(
            AndroidApkIdentityPolicy.PACKAGE_MISMATCH,
            rejection(identity = fixture.copy(packageName = "example.hostile")),
        )
        assertEquals(
            AndroidApkIdentityPolicy.VERSION_MISMATCH,
            rejection(request = request().copy(version = "1.2.1")),
        )
        assertEquals(AndroidApkIdentityPolicy.DOWNGRADE, rejection(installedVersionCode = 120L))
        assertEquals(AndroidApkIdentityPolicy.SDK_INCOMPATIBLE, rejection(deviceSdk = 23))
        assertEquals(
            AndroidApkIdentityPolicy.ABI_INCOMPATIBLE,
            rejection(deviceAbis = setOf("x86_64")),
        )
        assertEquals(
            AndroidApkIdentityPolicy.SIGNER_MISMATCH,
            rejection(
                identity = fixture.copy(
                    currentSignerSha256 = setOf(SIGNER_C),
                    signingLineageSha256 = emptySet(),
                ),
            ),
        )
        assertEquals(
            AndroidApkIdentityPolicy.SIGNER_MISMATCH,
            rejection(installedCurrentSigners = setOf(SIGNER_C), installedLineage = emptySet()),
        )
        assertEquals(
            AndroidApkIdentityPolicy.SIGNER_MISMATCH,
            rejection(
                identity = fixture.copy(
                    currentSignerSha256 = setOf(SIGNER_A, SIGNER_C),
                    hasMultipleSigners = true,
                ),
            ),
        )
    }

    @Test
    fun apkArchiveAbiReaderUsesOnlyBoundedNativeLibraryEntries() {
        val directory = Files.createTempDirectory("pokrov-apk-abi-").toFile()
        try {
            val apk = File(directory, "fixture.apk")
            ZipOutputStream(apk.outputStream()).use { zip ->
                listOf(
                    "AndroidManifest.xml",
                    "lib/arm64-v8a/libpokrov-core.so",
                    "lib/x86_64/libpokrov-core.so",
                    "assets/lib/not-an-abi.txt",
                ).forEach { name ->
                    zip.putNextEntry(ZipEntry(name))
                    zip.write(byteArrayOf(0x50, 0x4f, 0x4b))
                    zip.closeEntry()
                }
            }

            assertEquals(
                setOf("arm64-v8a", "x86_64"),
                AndroidApkArchiveAbis.read(apk),
            )
        } finally {
            directory.deleteRecursively()
        }
    }

    private fun fixtureIdentity(): AndroidApkIdentity {
        val properties = Properties()
        javaClass.classLoader
            ?.getResourceAsStream("android-update-identity.properties")
            ?.use(properties::load)
            ?: error("missing identity fixture")
        val abis = properties.getProperty("supported_abis")
            .split(',')
            .map(String::trim)
            .filter(String::isNotEmpty)
            .toSet()
        val identity = AndroidApkIdentity(
            packageName = properties.getProperty("package_name"),
            versionName = properties.getProperty("version_name"),
            versionCode = properties.getProperty("version_code").toLong(),
            minimumSdk = properties.getProperty("minimum_sdk").toInt(),
            supportedAbis = abis,
            currentSignerSha256 = setOf(properties.getProperty("current_signer_sha256")),
            signingLineageSha256 = setOf(properties.getProperty("lineage_signer_sha256")),
            hasMultipleSigners = false,
        )
        assertTrue(identity.currentSignerSha256.none(String::isBlank))
        return identity
    }

    private fun request() = AndroidClientUpdateRequest(
        url = "https://github.com/Kiwunaka/pokrov/releases/download/v1.2.0/pokrov.apk",
        sha256 = "d".repeat(64),
        size = 100L,
        channel = "stable",
        version = "1.2.0",
    )

    private companion object {
        const val PACKAGE_NAME = "space.pokrov.pokrov_android_shell"
        const val SIGNER_A =
            "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
        const val SIGNER_C =
            "CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC"
    }
}
