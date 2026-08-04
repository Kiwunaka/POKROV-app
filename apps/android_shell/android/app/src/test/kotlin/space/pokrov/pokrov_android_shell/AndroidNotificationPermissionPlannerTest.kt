package space.pokrov.pokrov_android_shell

import org.junit.Assert.assertEquals
import org.junit.Test

class AndroidNotificationPermissionPlannerTest {
    @Test
    fun grantAndPreAndroid13_continueWithoutARequest() {
        assertEquals(
            AndroidNotificationPermissionAction.CONTINUE,
            AndroidNotificationPermissionPlanner.decide(
                sdkInt = 32,
                granted = false,
                askedBefore = false,
                shouldShowRationale = false,
                requestInFlight = false,
            ),
        )
        assertEquals(
            AndroidNotificationPermissionAction.CONTINUE,
            AndroidNotificationPermissionPlanner.decide(
                sdkInt = 33,
                granted = true,
                askedBefore = true,
                shouldShowRationale = false,
                requestInFlight = false,
            ),
        )
    }

    @Test
    fun firstAndroid13Connect_requestsNotificationPermissionOnce() {
        assertEquals(
            AndroidNotificationPermissionAction.REQUEST,
            AndroidNotificationPermissionPlanner.decide(
                sdkInt = 33,
                granted = false,
                askedBefore = false,
                shouldShowRationale = false,
                requestInFlight = false,
            ),
        )
        assertEquals(
            AndroidNotificationPermissionAction.WAIT_FOR_RESULT,
            AndroidNotificationPermissionPlanner.decide(
                sdkInt = 33,
                granted = false,
                askedBefore = true,
                shouldShowRationale = true,
                requestInFlight = true,
            ),
        )
    }

    @Test
    fun denialContinuesWithWarningUnlessAndroidRecommendsAnotherRequest() {
        assertEquals(
            AndroidNotificationPermissionAction.CONTINUE_WITH_WARNING,
            AndroidNotificationPermissionPlanner.decide(
                sdkInt = 33,
                granted = false,
                askedBefore = true,
                shouldShowRationale = false,
                requestInFlight = false,
            ),
        )
        assertEquals(
            AndroidNotificationPermissionAction.REQUEST,
            AndroidNotificationPermissionPlanner.decide(
                sdkInt = 33,
                granted = false,
                askedBefore = true,
                shouldShowRationale = true,
                requestInFlight = false,
            ),
        )
    }
}
