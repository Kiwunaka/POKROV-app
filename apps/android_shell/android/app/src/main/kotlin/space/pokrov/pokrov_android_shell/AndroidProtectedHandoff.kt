package space.pokrov.pokrov_android_shell

/** Owns replacement cancellation; protection survives settlement until explicit stop. */
internal class AndroidProtectedHandoff {
    private var request: String? = null
    private var replacing = false
    private var cancelled = false
    @Volatile var retainsTun: Boolean = false
        private set

    @Synchronized fun begin(id: String): Boolean {
        if (replacing) return false
        request = id
        replacing = true
        cancelled = false
        retainsTun = true
        return true
    }

    @Synchronized fun owns(id: String): Boolean = request == id && !cancelled
    @Synchronized fun isCancelled(id: String): Boolean = request == id && cancelled
    @Synchronized fun cancel(id: String): Boolean {
        if (request != id) return false
        cancelled = true
        return true
    }
    @Synchronized fun settle(id: String) {
        if (request == id) replacing = false
    }
    @Synchronized fun <T> publishTun(action: () -> T): T {
        check(!retainsTun || !cancelled) { "protected replacement cancelled" }
        return action()
    }
    @Synchronized fun release() {
        request = null
        replacing = false
        cancelled = true
        retainsTun = false
    }
}
