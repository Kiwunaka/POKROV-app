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
    fun directUpdaterAloneUsesPrivateFileProviderAndInstallerPermission() {
        val commonManifest = File("src/main/AndroidManifest.xml").readText()
        val directManifest = File("src/direct/AndroidManifest.xml").readText()
        val storeManifest = File("src/store/AndroidManifest.xml").readText()
        val paths = File("src/main/res/xml/pokrov_update_paths.xml").readText()

        assertFalse(commonManifest.contains("android.permission.REQUEST_INSTALL_PACKAGES"))
        assertFalse(commonManifest.contains("androidx.core.content.FileProvider"))
        assertFalse(storeManifest.contains("android.permission.REQUEST_INSTALL_PACKAGES"))
        assertFalse(storeManifest.contains("androidx.core.content.FileProvider"))
        assertTrue(directManifest.contains("android.permission.REQUEST_INSTALL_PACKAGES"))
        assertTrue(directManifest.contains("androidx.core.content.FileProvider"))
        assertTrue(directManifest.contains("android:authorities=\"\${applicationId}.updates\""))
        assertTrue(directManifest.contains("android:exported=\"false\""))
        assertTrue(directManifest.contains("@xml/pokrov_update_paths"))
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
