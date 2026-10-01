import Foundation
import IOKit.pwr_mgt

/// Holds or releases the one IOPM assertion type that blocks idle *display*
/// sleep without touching system sleep or the screensaver/lock timer — those
/// run on a separate OS schedule, so "require password after screen saver"
/// keeps firing even while this is held. Abstracted so StayAwake is
/// unit-testable without talking to the real power management subsystem,
/// mirroring TouchBarRecovery's ProcessRunning pattern.
protocol PowerAssertionManaging: Sendable {
    /// Returns whether the assertion is now held.
    func acquire(reason: String) -> Bool
    func release()
}

/// Real implementation: wraps IOPMAssertionCreateWithName/Release.
struct RealPowerAssertionManager: PowerAssertionManaging {
    private final class AssertionBox: @unchecked Sendable {
        var id: IOPMAssertionID = 0
    }
    private let box = AssertionBox()

    func acquire(reason: String) -> Bool {
        var id: IOPMAssertionID = 0
        let result = IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            reason as CFString,
            &id
        )
        guard result == kIOReturnSuccess else { return false }
        box.id = id
        return true
    }

    func release() {
        guard box.id != 0 else { return }
        IOPMAssertionRelease(box.id)
        box.id = 0
    }
}

/// User preference: keep the display from idle-sleeping while the app runs.
/// Persisted so it survives relaunch; the assertion itself is process-scoped
/// and does not need explicit crash recovery — macOS releases it automatically
/// if this process dies, unlike the display-off state DisplayManager tracks.
/// `@unchecked Sendable`: `isHoldingAssertion` is normally only touched from
/// the main thread, except for the resume closure returned by
/// `suspendForDisplaySleepCycle()`, which TouchBarRecovery invokes from its
/// background queue — safe because that window never overlaps with another
/// caller (nothing else toggles Stay Awake mid-nudge).
final class StayAwake: @unchecked Sendable {
    private let defaults: UserDefaults
    private let assertionManager: PowerAssertionManaging
    private let defaultsKey = "StayAwakeEnabled"
    private var isHoldingAssertion = false

    init(
        defaults: UserDefaults = .standard,
        assertionManager: PowerAssertionManaging = RealPowerAssertionManager()
    ) {
        self.defaults = defaults
        self.assertionManager = assertionManager
    }

    /// Defaults to `false` — this is an opt-in convenience, not a safety
    /// default like auto-revert.
    var isEnabled: Bool {
        get { defaults.bool(forKey: defaultsKey) }
        set {
            defaults.set(newValue, forKey: defaultsKey)
            setHoldingAssertion(newValue)
        }
    }

    /// Call once at launch to apply whatever was persisted from last session.
    func applyPersistedPreference() {
        setHoldingAssertion(isEnabled)
    }

    /// Call before quit. Not strictly required for correctness (the OS
    /// releases the assertion when the process exits either way), but it
    /// keeps the held/not-held bookkeeping honest for a clean shutdown.
    func releaseIfNeeded() {
        setHoldingAssertion(false)
    }

    /// Temporarily releases the assertion so a forced display sleep→wake
    /// cycle (TouchBarRecovery's `nudge()`, which resignals the Touch Bar's
    /// DFR session) isn't fought by macOS power management — with the
    /// idle-display-sleep assertion held, the OS can re-wake the display out
    /// from under `pmset displaysleepnow` almost immediately, so the "real"
    /// sleep→wake transition the Touch Bar needs never actually completes.
    /// Returns a closure that restores the assertion afterward (a no-op if
    /// it wasn't held).
    func suspendForDisplaySleepCycle() -> @Sendable () -> Void {
        guard isHoldingAssertion else { return {} }
        assertionManager.release()
        isHoldingAssertion = false
        return { [self] in
            isHoldingAssertion = assertionManager.acquire(reason: "Sasih: Stay Awake")
        }
    }

    private func setHoldingAssertion(_ shouldHold: Bool) {
        guard shouldHold != isHoldingAssertion else { return }
        if shouldHold {
            isHoldingAssertion = assertionManager.acquire(reason: "Sasih: Stay Awake")
        } else {
            assertionManager.release()
            isHoldingAssertion = false
        }
    }
}
