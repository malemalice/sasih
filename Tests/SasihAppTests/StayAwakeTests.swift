import Testing
@testable import SasihApp

final class StayAwakeTests {
    @Test func defaultsToDisabled() {
        #expect(StayAwakeScenario.defaultsToDisabled())
    }

    @Test func enablingAcquiresAssertionAndPersists() {
        #expect(StayAwakeScenario.enablingAcquiresAssertionAndPersists())
    }

    @Test func disablingAfterEnablingReleasesAssertion() {
        #expect(StayAwakeScenario.disablingAfterEnablingReleasesAssertion())
    }

    @Test func settingSameValueTwiceDoesNotReacquire() {
        #expect(StayAwakeScenario.settingSameValueTwiceDoesNotReacquire())
    }

    @Test func failedAcquireLeavesStateNotHeldSoDisableIsANoOp() {
        #expect(StayAwakeScenario.failedAcquireLeavesStateNotHeldSoDisableIsANoOp())
    }

    @Test func applyPersistedPreferenceAcquiresWhenPreviouslyEnabled() {
        #expect(StayAwakeScenario.applyPersistedPreferenceAcquiresWhenPreviouslyEnabled())
    }

    @Test func releaseIfNeededReleasesOnlyWhenHeld() {
        #expect(StayAwakeScenario.releaseIfNeededReleasesOnlyWhenHeld())
    }

    @Test func suspendForDisplaySleepCycleReleasesThenResumeReacquiresWhenHeld() {
        #expect(StayAwakeScenario.suspendForDisplaySleepCycleReleasesThenResumeReacquiresWhenHeld())
    }

    @Test func suspendForDisplaySleepCycleIsNoOpWhenNotHeld() {
        #expect(StayAwakeScenario.suspendForDisplaySleepCycleIsNoOpWhenNotHeld())
    }
}
