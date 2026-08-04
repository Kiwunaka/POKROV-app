package space.pokrov.pokrov_android_shell

internal data class AndroidTunPackagePlan(
    val allowedPackages: List<String>,
    val disallowedPackages: List<String>,
    val isValid: Boolean = true,
)

internal object AndroidTunPackagePlanner {
    fun plan(
        appPackage: String,
        includedPackages: List<String>,
        excludedPackages: List<String>,
        selectedAppsMode: Boolean = false,
    ): AndroidTunPackagePlan {
        val allowed = includedPackages
            .map(String::trim)
            .filter(String::isNotEmpty)
            .distinct()
        if (allowed.isNotEmpty()) {
            return AndroidTunPackagePlan(
                allowedPackages = allowed,
                disallowedPackages = emptyList(),
            )
        }
        if (selectedAppsMode) {
            return AndroidTunPackagePlan(
                allowedPackages = emptyList(),
                disallowedPackages = emptyList(),
                isValid = false,
            )
        }

        val disallowed = buildList {
            add(appPackage)
            addAll(excludedPackages)
        }
            .map(String::trim)
            .filter(String::isNotEmpty)
            .distinct()
        return AndroidTunPackagePlan(
            allowedPackages = emptyList(),
            disallowedPackages = disallowed,
        )
    }

    fun hasRequiredAppliedAllowList(
        selectedAppsMode: Boolean,
        appliedAllowedPackageCount: Int,
    ): Boolean = !selectedAppsMode || appliedAllowedPackageCount > 0
}
