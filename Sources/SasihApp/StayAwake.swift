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
/// `@unchecked Sendable`: `isHoldingAssertion` is touched from the main
/// thread *and* from the resume closure returned by
/// `suspendForDisplaySleepCycle()`, which TouchBarRecovery invokes from its
/// background queue — that window can overlap with the user toggling Stay
/// Awake, so access is serialized through `lock`.
final class StayAwake: @unchecked Sendable {
    private let defaults: UserDefaults
    private let assertionManager: PowerAssertionManaging
    private let defaultsKey = "StayAwakeEnabled"
    private let lock = NSLock()
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
        // The lock is held across the hardware call itself, not just the
        // flag, for the whole suspend/resume pair below — see
        // `setHoldingAssertion` for why: `assertionManager` isn't safe to
        // call concurrently, and this closure runs on a background queue
        // that can overlap with a main-thread toggle.
        lock.lock()
        let wasHolding = isHoldingAssertion
        if wasHolding {
            isHoldingAssertion = false
            assertionManager.release()
        }
        lock.unlock()
        guard wasHolding else { return {} }
        // Re-check `isEnabled` (rather than unconditionally reacquiring) so
        // a Stay Awake toggle that happened while the nudge was in flight
        // isn't silently undone.
        return { [self] in
            lock.lock()
            defer { lock.unlock() }
            // A manual toggle that landed while the nudge was in flight may
            // already have reacquired the assertion. Without this check
            // we'd acquire a second time here, overwriting
            // RealPowerAssertionManager's single stored IOPMAssertionID and
            // leaking the first one for the rest of the process's life.
            guard !isHoldingAssertion else { return }
            isHoldingAssertion = isEnabled && assertionManager.acquire(reason: "Sasih: Stay Awake")
        }
    }

    /// Holds `lock` across the `assertionManager` call itself (not just the
    /// `isHoldingAssertion` flag): `RealPowerAssertionManager` stores a
    /// single unsynchronized `IOPMAssertionID`, and the resume closure above
    /// runs on a background queue that can overlap with a toggle on the main
    /// thread. Releasing the lock between the hardware call and the flag
    /// update would let both sides call `acquire`/`release` concurrently —
    /// racing on that stored ID and leaking or losing an assertion — which a
    /// lock around the flag alone cannot prevent.
    private func setHoldingAssertion(_ shouldHold: Bool) {
        lock.lock()
        defer { lock.unlock() }
        guard shouldHold != isHoldingAssertion else { return }
        if shouldHold {
            isHoldingAssertion = assertionManager.acquire(reason: "Sasih: Stay Awake")
        } else {
            assertionManager.release()
            isHoldingAssertion = false
        }
    }
}
