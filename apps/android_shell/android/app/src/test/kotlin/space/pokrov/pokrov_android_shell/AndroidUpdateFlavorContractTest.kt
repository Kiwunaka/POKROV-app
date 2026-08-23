package space.pokrov.pokrov_android_shell

import java.io.File
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AndroidUpdateFlavorContractTest {
    @Test
    fun gradleDeclaresDirectAndStoreReleaseAuthority() {
        val gradle = File("build.gradle").readText()

        assertTrue(gradle.contains("flavorDimensions += \"distribution\""))
        assertTrue(gradle.contains("productFlavors"))
        assertTrue(gradle.contains("direct {"))
        assertTrue(gradle.contains("store {"))
        assertTrue(gradle.contains("POKROV_DIRECT_UPDATE_ENABLED"))
    }

    @Test
    fun storeSourceHasNoDirectApkInstallerReachability() {
        val store = source("store")
        val direct = source("direct")

        assertTrue(store.contains("com.android.vending"))
        assertTrue(store.contains("market://details"))
        assertFalse(store.contains("FileProvider"))
        assertFalse(store.contains("REQUEST_INSTALL_PACKAGES"))
        assertFalse(store.contains("ACTION_MANAGE_UNKNOWN_APP_SOURCES"))
        assertFalse(store.contains("application/vnd.android.package-archive"))

        assertTrue(direct.contains("FileProvider.getUriForFile"))
        assertTrue(direct.contains("GET_SIGNING_CERTIFICATES"))
        assertTrue(direct.contains("AndroidApkIdentityPolicy.rejection("))
        assertTrue(direct.contains("if (verifyUpdate(activity, destination, request"))
        assertTrue(direct.contains("if (!verifyUpdate(activity, apk, update.request))"))
    }

    private fun source(flavor: String): String = File(
        "src/$flavor/kotlin/space/pokrov/pokrov_android_shell/" +
            "AndroidClientUpdateInstaller.kt",
    ).readText()
}
