package space.pokrov.pokrov_android_shell

import java.io.File
import org.junit.Assert.assertTrue
import org.junit.Test

class AndroidManifestPermissionsTest {
    @Test
    fun manifestDeclaresNetworkPermissionsRequiredByPlatformMonitor() {
        val manifest = File("src/main/AndroidManifest.xml").readText()

        assertTrue(
            "Android manifest must declare ACCESS_NETWORK_STATE for ConnectivityManager-backed runtime monitoring.",
            manifest.contains("android.permission.ACCESS_NETWORK_STATE"),
        )
        assertTrue(
            "Android manifest must declare CHANGE_NETWORK_STATE for requestNetwork-based default interface monitoring.",
            manifest.contains("android.permission.CHANGE_NETWORK_STATE"),
        )
    }
}
