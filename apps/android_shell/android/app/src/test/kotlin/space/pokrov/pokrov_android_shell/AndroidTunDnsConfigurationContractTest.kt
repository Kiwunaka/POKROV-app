package space.pokrov.pokrov_android_shell

import java.io.File
import org.junit.Assert.assertTrue
import org.junit.Test

class AndroidTunDnsConfigurationContractTest {
    @Test
    fun tunAdvertisesTheRuntimeDnsAddressBeforeItIsEstablished() {
        val source = File(
            "src/main/kotlin/space/pokrov/pokrov_android_shell/PokrovRuntimeVpnService.kt",
        ).readText()

        val dnsAddress = source.indexOf("options.getDNSServerAddress().getValue()")
        val advertised = source.indexOf(".let(builder::addDnsServer)")
        val established = source.indexOf("val tun = builder.establish()")

        assertTrue(dnsAddress >= 0)
        assertTrue(advertised > dnsAddress)
        assertTrue(established > advertised)
    }
}
