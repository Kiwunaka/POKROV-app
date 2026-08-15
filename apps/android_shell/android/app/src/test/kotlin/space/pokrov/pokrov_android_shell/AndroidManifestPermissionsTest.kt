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
    fun verifiedUpdaterUsesPrivateFileProviderAndInstallerPermission() {
        val manifest = File("src/main/AndroidManifest.xml").readText()
        val paths = File("src/main/res/xml/pokrov_update_paths.xml").readText()

        assertTrue(manifest.contains("android.permission.REQUEST_INSTALL_PACKAGES"))
        assertTrue(manifest.contains("androidx.core.content.FileProvider"))
        assertTrue(manifest.contains("android:authorities=\"\${applicationId}.updates\""))
        assertTrue(manifest.contains("android:exported=\"false\""))
        assertTrue(manifest.contains("@xml/pokrov_update_paths"))
        assertTrue(paths.contains("<cache-path"))
        assertTrue(paths.contains("path=\"updates/\""))
    }

    @Test
    fun quickSettingsTileUsesActiveRefreshWithoutToggleableMetadata() {
        val manifest = File("src/main/AndroidManifest.xml").readText()

        assertFalse(
            "Runtime-owned state must not depend on OEM toggleable metadata.",
            manifest.contains("android.service.quicksettings.TOGGLEABLE_TILE"),
        )
        assertTrue(
            "Active mode is required for requestListeningState to refresh OEM-cached tiles.",
            manifest.contains("android.service.quicksettings.ACTIVE_TILE"),
        )
    }
}
