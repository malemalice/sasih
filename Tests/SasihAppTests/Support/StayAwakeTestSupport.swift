import Foundation
@testable import SasihApp

/// Kept in a file that does NOT import `Testing` — see
/// DisplayIDStoreTestSupport.swift in SasihCoreTests for why: a missing
/// `_Testing_Foundation` cross-import overlay in this machine's Command Line
/// Tools install breaks importing Foundation and Testing together in the
/// same file. The `@Test` cases live in StayAwakeTests.swift and just call
/// into this scenario type.
final class FakeAssertionManager: PowerAssertionManaging, @unchecked Sendable {
    var acquireCallCount = 0
    var releaseCallCount = 0
    var shouldSucceed = true
    var lastReason: String?

    func acquire(reason: String) -> Bool {
        acquireCallCount += 1
        lastReason = reason
        return shouldSucceed
    }

    func release() {
        releaseCallCount += 1
    }
}

enum StayAwakeScenario {
    private static func withStayAwake<T>(
        shouldSucceed: Bool = true,
        _ body: (StayAwake, FakeAssertionManager, UserDefaults) -> T
    ) -> T {
        let suiteName = "StayAwakeTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let assertionManager = FakeAssertionManager()
        assertionManager.shouldSucceed = shouldSucceed
        let stayAwake = StayAwake(defaults: defaults, assertionManager: assertionManager)
        return body(stayAwake, assertionManager, defaults)
    }

    static func defaultsToDisabled() -> Bool {
        withStayAwake { stayAwake, _, _ in stayAwake.isEnabled == false }
    }

    static func enablingAcquiresAssertionAndPersists() -> Bool {
        withStayAwake { stayAwake, assertionManager, defaults in
            stayAwake.isEnabled = true
            return assertionManager.acquireCallCount == 1
                && assertionManager.releaseCallCount == 0
                && defaults.bool(forKey: "StayAwakeEnabled") == true
        }
    }

    static func disablingAfterEnablingReleasesAssertion() -> Bool {
        withStayAwake { stayAwake, assertionManager, _ in
            stayAwake.isEnabled = true
            stayAwake.isEnabled = false
            return assertionManager.acquireCallCount == 1 && assertionManager.releaseCallCount == 1
        }
    }

    static func settingSameValueTwiceDoesNotReacquire() -> Bool {
        withStayAwake { stayAwake, assertionManager, _ in
            stayAwake.isEnabled = true
            stayAwake.isEnabled = true
            return assertionManager.acquireCallCount == 1
        }
    }

    static func failedAcquireLeavesStateNotHeldSoDisableIsANoOp() -> Bool {
        withStayAwake(shouldSucceed: false) { stayAwake, assertionManager, _ in
            stayAwake.isEnabled = true
            stayAwake.isEnabled = false
            return assertionManager.acquireCallCount == 1 && assertionManager.releaseCallCount == 0
        }
    }

    static func applyPersistedPreferenceAcquiresWhenPreviouslyEnabled() -> Bool {
        let suiteName = "StayAwakeTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set(true, forKey: "StayAwakeEnabled")
        let assertionManager = FakeAssertionManager()
        let stayAwake = StayAwake(defaults: defaults, assertionManager: assertionManager)
        stayAwake.applyPersistedPreference()
        return assertionManager.acquireCallCount == 1
    }

    static func releaseIfNeededReleasesOnlyWhenHeld() -> Bool {
        withStayAwake { stayAwake, assertionManager, _ in
            stayAwake.releaseIfNeeded()
            guard assertionManager.releaseCallCount == 0 else { return false }
            stayAwake.isEnabled = true
            stayAwake.releaseIfNeeded()
            return assertionManager.releaseCallCount == 1
        }
    }

    static func suspendForDisplaySleepCycleReleasesThenResumeReacquiresWhenHeld() -> Bool {
        withStayAwake { stayAwake, assertionManager, _ in
            stayAwake.isEnabled = true
            let resume = stayAwake.suspendForDisplaySleepCycle()
            guard assertionManager.releaseCallCount == 1, assertionManager.acquireCallCount == 1 else { return false }
            resume()
            return assertionManager.acquireCallCount == 2 && assertionManager.releaseCallCount == 1
        }
    }

    static func suspendForDisplaySleepCycleIsNoOpWhenNotHeld() -> Bool {
        withStayAwake { stayAwake, assertionManager, _ in
            let resume = stayAwake.suspendForDisplaySleepCycle()
            resume()
            return assertionManager.acquireCallCount == 0 && assertionManager.releaseCallCount == 0
        }
    }
}
