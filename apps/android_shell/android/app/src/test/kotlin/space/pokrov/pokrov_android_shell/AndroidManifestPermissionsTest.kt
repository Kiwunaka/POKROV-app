package space.pokrov.pokrov_android_shell

import java.io.File
import org.junit.Assert.assertFalse
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

    @Test
    fun quickSettingsTileIsAStandardStateNeutralAction() {
        val manifest = File("src/main/AndroidManifest.xml").readText()

        assertFalse(
            "The state-neutral action must not expose stale switch semantics.",
            manifest.contains("android.service.quicksettings.TOGGLEABLE_TILE"),
        )
        assertFalse(
            "Standard mode lets every OEM refresh the tile whenever the shade opens.",
            manifest.contains("android.service.quicksettings.ACTIVE_TILE"),
        )
    }
}
