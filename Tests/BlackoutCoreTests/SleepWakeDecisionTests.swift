import Testing
@testable import BlackoutCore

struct SleepWakeDecisionTests {
    @Test func wasOnBeforeSleep_ExternalPresent_DoesNothing() {
        #expect(SleepWakeDecision.wakeAction(wasOffBeforeSleep: false, externalPresentOnWake: true) == .doNothing)
    }

    @Test func wasOnBeforeSleep_ExternalAbsent_DoesNothing() {
        #expect(SleepWakeDecision.wakeAction(wasOffBeforeSleep: false, externalPresentOnWake: false) == .doNothing)
    }

    @Test func wasOffBeforeSleep_ExternalStillPresent_ReappliesOff() {
        #expect(SleepWakeDecision.wakeAction(wasOffBeforeSleep: true, externalPresentOnWake: true) == .reapplyOff)
    }

    @Test func wasOffBeforeSleep_ExternalGone_LeavesOn() {
        // Never reapply "off" if the external that justified it is gone on wake —
        // matches the "never strand the user" guarantee even across sleep/wake.
        #expect(SleepWakeDecision.wakeAction(wasOffBeforeSleep: true, externalPresentOnWake: false) == .leaveOn)
    }
}
