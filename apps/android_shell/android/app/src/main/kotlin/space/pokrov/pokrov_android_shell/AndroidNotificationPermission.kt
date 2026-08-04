package space.pokrov.pokrov_android_shell

import android.content.Context

internal enum class AndroidNotificationPermissionAction {
    CONTINUE,
    REQUEST,
    CONTINUE_WITH_WARNING,
    WAIT_FOR_RESULT,
}

internal object AndroidNotificationPermissionPlanner {
    fun decide(
        sdkInt: Int,
        granted: Boolean,
        askedBefore: Boolean,
        shouldShowRationale: Boolean,
        requestInFlight: Boolean,
    ): AndroidNotificationPermissionAction = when {
        sdkInt < 33 || granted -> AndroidNotificationPermissionAction.CONTINUE
        requestInFlight -> AndroidNotificationPermissionAction.WAIT_FOR_RESULT
        !askedBefore || shouldShowRationale -> AndroidNotificationPermissionAction.REQUEST
        else -> AndroidNotificationPermissionAction.CONTINUE_WITH_WARNING
    }
}

internal object AndroidNotificationPermissionStore {
    private const val PREFERENCES_NAME = "pokrov_notification_permission"
    private const val KEY_ASKED = "asked"

    fun wasAsked(context: Context): Boolean =
        context.getSharedPreferences(PREFERENCES_NAME, Context.MODE_PRIVATE)
            .getBoolean(KEY_ASKED, false)

    fun markAsked(context: Context) {
        context.getSharedPreferences(PREFERENCES_NAME, Context.MODE_PRIVATE)
            .edit()
            .putBoolean(KEY_ASKED, true)
            .apply()
    }
}
