package space.pokrov.pokrov_android_shell

import android.os.SystemClock

/** Process-local Flutter request ownership; never persisted or logged. */
internal object AndroidConnectRequestOwner {
    private var current: String? = null
    private var cancelled = false
    private var coreDigest: String? = null
    private var profileDigest: String? = null
    private var deadline: AndroidConnectDeadline? = null
    private var promotedUntilElapsed: Long? = null
    private var networkGeneration: Long? = null
    private var preparedNetwork: AndroidTransportNetworkContext? = null
    private var preparedNetworkRef: String? = null
    private var networkDetachedFromBridge = false
    private var service: PokrovRuntimeVpnService? = null
    private var stopped = false
    private var lastStopped: String? = null
    @Volatile private var proofPending = false
    @Volatile private var leaseActive = false

    // Snapshot reads must not take this monitor while holding RuntimeState's
    // lock: bound progress takes those locks in the opposite direction.
    fun requiresTransportProof(): Boolean = proofPending
    fun hasPromotedTransportLease(): Boolean = leaseActive

    fun valid(value: String): Boolean = value.matches(Regex("[0-9a-f]{32}"))

    @Synchronized
    fun knows(request: String): Boolean = current == request || lastStopped == request

    @Synchronized
    fun begin(request: String): Boolean {
        require(valid(request))
        if (request == lastStopped) return false
        if (coreDigest != null && !stopped) return false
        if (current == request) return !cancelled
        current = request
        cancelled = false
        coreDigest = null
        profileDigest = null
        deadline = null
        promotedUntilElapsed = null
        networkGeneration = null
        preparedNetwork = null
        preparedNetworkRef = null
        networkDetachedFromBridge = false
        service = null
        stopped = false
        proofPending = false
        leaseActive = false
        return true
    }

    @Synchronized
    fun beginBound(request: String, expectedCore: String, expectedProfile: String,
        expectedDeadline: AndroidConnectDeadline, network: AndroidTransportNetworkContext,
        networkRef: String): Boolean {
        require(valid(request))
        if (!network.matches(networkRef)) return false
        if (request == lastStopped) return false
        if (current == request) {
            return !cancelled && !stopped && coreDigest == expectedCore && profileDigest == expectedProfile &&
                deadline == expectedDeadline && expectedDeadline.isCurrent() &&
                preparedNetwork === network && preparedNetworkRef == networkRef && networkIsCurrent()
        }
        if (coreDigest != null && !stopped) return false
        current = request
        cancelled = false
        coreDigest = expectedCore
        profileDigest = expectedProfile
        deadline = expectedDeadline
        promotedUntilElapsed = null
        networkGeneration = null
        preparedNetwork = network
        preparedNetworkRef = networkRef
        networkDetachedFromBridge = false
        service = null
        stopped = false
        proofPending = true
        leaseActive = false
        return true
    }

    @Synchronized
    fun blocksStart(request: String?): Boolean = coreDigest != null && !stopped && current != request

    @Synchronized
    fun admitService(request: String, owner: PokrovRuntimeVpnService): Boolean {
        if (current != request || cancelled || stopped || deadline?.isCurrent() == false || !networkIsCurrent()) return false
        if (coreDigest == null) return true
        if (service != null) return false
        service = owner
        return true
    }

    @Synchronized
    fun serviceFor(request: String): PokrovRuntimeVpnService? =
        if (current == request && coreDigest != null && !stopped) service else null

    @Synchronized
    fun ownsService(owner: PokrovRuntimeVpnService): Boolean = service === owner && !stopped

    @Synchronized
    fun bindNetwork(request: String, owner: PokrovRuntimeVpnService, generation: Long): Boolean {
        if (current != request || service !== owner || coreDigest == null || cancelled || stopped ||
            deadline?.isCurrent() != true || AndroidDefaultNetworkMonitor.contextGeneration() != generation ||
            preparedNetworkRef?.let { preparedNetwork?.matchesRuntimeNetwork(it) } != true) return false
        if (networkGeneration != null) return networkGeneration == generation
        networkGeneration = generation
        return true
    }

    @Synchronized
    fun settleBeforeServiceAdmission(request: String): Boolean {
        if (lastStopped == request) return true
        if (current != request || coreDigest == null || !cancelled || service != null) return false
        stopped = true
        lastStopped = request
        proofPending = false
        leaseActive = false
        return true // cancelled ownership fences every later permission callback/START
    }

    fun serviceStopped(request: String, owner: PokrovRuntimeVpnService): Boolean {
        val (settled, detachedNetwork) = synchronized(this) {
            if (current != request || service !== owner) return@synchronized (lastStopped == request) to null
            cancelled = true
            stopped = true
            service = null
            lastStopped = request
            proofPending = false
            leaseActive = false
            val detached = if (networkDetachedFromBridge) preparedNetwork else null
            networkDetachedFromBridge = false
            if (detached != null) preparedNetwork = null
            true to detached
        }
        detachedNetwork?.close()
        return settled
    }

    // Activity teardown owns an unpromoted attempt, but hands an accepted lease's
    // observer to the service so UI closure cannot revoke the physical-network ref.
    fun bridgeClosing(network: AndroidTransportNetworkContext): Boolean {
        val target = synchronized(this) {
            if (preparedNetwork !== network || stopped) return false
            if (promotedUntilElapsed?.let { SystemClock.elapsedRealtime() < it } == true && !cancelled && leaseActive) {
                networkDetachedFromBridge = true
                return true
            }
            cancelled = true
            if (service == null) {
                stopped = true
                lastStopped = current
                proofPending = false
                leaseActive = false
                return false
            }
            current?.let { it to service }
        }
        target?.let { (request, owner) ->
            owner?.cancelAndConfirmConnectStopped(request, stopReason = "client_exit") {}
        }
        return false
    }

    @Synchronized
    fun isStopped(request: String): Boolean = lastStopped == request

    @Synchronized
    fun ownsStart(request: String, expectedCore: String?, expectedProfile: String,
        expectedDeadline: AndroidConnectDeadline?): Boolean =
        current == request && !cancelled && coreDigest == expectedCore &&
            (profileDigest == null || profileDigest == expectedProfile) && deadline == expectedDeadline &&
            (deadline?.isCurrent() != false) && networkIsCurrent()

    @Synchronized
    fun promote(request: String, owner: PokrovRuntimeVpnService, expectedProfile: String,
        activeUntilElapsed: Long): Boolean {
        if (current != request || service !== owner || cancelled || stopped ||
            coreDigest == null || profileDigest != expectedProfile || deadline?.isCurrent() != true ||
            activeUntilElapsed <= SystemClock.elapsedRealtime() || !networkIsCurrent()) return false
        promotedUntilElapsed = activeUntilElapsed
        deadline = null
        proofPending = false
        leaseActive = true
        return true
    }

    @Synchronized
    fun markTransportLeaseTerminated(request: String, owner: PokrovRuntimeVpnService,
        expectedProfile: String): Boolean {
        if (current != request || service !== owner || profileDigest != expectedProfile ||
            cancelled || stopped || !leaseActive || networkDetachedFromBridge) return false
        proofPending = true
        leaseActive = false
        return true
    }

    @Synchronized
    fun owns(request: String): Boolean = current == request && !cancelled &&
        deadline?.isCurrent() != false &&
        (promotedUntilElapsed == null || SystemClock.elapsedRealtime() < promotedUntilElapsed!!) && networkIsCurrent()

    @Synchronized
    fun snapshotForBoundRequest(request: String): Map<String, Any?>? {
        val core = coreDigest ?: return null
        val profile = profileDigest ?: return null
        if (current != request || cancelled || stopped ||
            (deadline?.isCurrent() != true && (promotedUntilElapsed == null ||
                SystemClock.elapsedRealtime() >= promotedUntilElapsed!!)) || !networkIsCurrent()) return null
        val completed = service?.hasCompletedBoundStart(request, profile) == true
        if (completed && networkGeneration == null) return null
        return AndroidRuntimeState.snapshotForBoundConnect(core, profile, completed)
    }

    @Synchronized
    fun expire(request: String): Boolean {
        if (current != request || cancelled || deadline?.isCurrent() != false) return false
        cancelled = true
        return true
    }

    @Synchronized
    fun ownsCancellation(request: String): Boolean = current == request && cancelled

    @Synchronized
    fun cancel(request: String): Boolean {
        if (current != request) return false
        cancelled = true
        return true
    }

    @Synchronized
    fun invalidate() { cancelled = true }

    // Called under this owner's monitor. Network callbacks release their own
    // lock before entering here; service cancellation happens outside both.
    private fun networkIsCurrent(): Boolean =
        (preparedNetworkRef == null || preparedNetwork?.matches(preparedNetworkRef!!) == true) &&
        (networkGeneration == null || networkGeneration == AndroidDefaultNetworkMonitor.contextGeneration())

    fun cancelIfNetworkChanged() {
        val target = synchronized(this) {
            if (coreDigest == null || stopped || cancelled || networkIsCurrent()) return
            cancelled = true
            current?.let { it to service }
        } ?: return
        // Before admission this fences permission callbacks; after admission
        // the service still owns its resources until exact settlement.
        target.second?.cancelAndConfirmConnectStopped(target.first, stopReason = "network_context_changed") {}
    }
}
