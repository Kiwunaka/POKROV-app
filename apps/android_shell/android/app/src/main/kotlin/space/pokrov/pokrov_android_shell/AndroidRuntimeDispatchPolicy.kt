package space.pokrov.pokrov_android_shell

import java.util.concurrent.Executor

/** Drops stale work and treats a shutting-down executor as an expected lifecycle event. */
internal object AndroidRuntimeDispatchPolicy {
    fun initialize(
        scope: AndroidLifecycleTaskScope,
        postToOwner: (() -> Unit) -> Unit,
        task: () -> Map<String, Any?>,
        complete: (Result<Map<String, Any?>>) -> Unit,
    ): Boolean = scope.execute {
        val outcome = runCatching(task)
        postToOwner {
            if (scope.isActive()) {
                complete(outcome)
            }
        }
    }

    fun dispatch(
        executor: Executor,
        shouldRun: () -> Boolean,
        task: () -> Unit,
    ): Boolean {
        if (!shouldRun()) {
            return false
        }
        return runCatching {
            executor.execute {
                if (shouldRun()) {
                    task()
                }
            }
        }.isSuccess
    }
}
