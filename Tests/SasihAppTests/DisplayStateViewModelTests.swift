import CoreGraphics
import SwiftUI
import Testing
import SasihCore
@testable import SasihApp

private final class FakeConfigurer: DisplayConfiguring {
    var shouldSucceed = true
    func setDisplay(_ id: CGDirectDisplayID, enabled: Bool) -> Bool { shouldSucceed }
}

private final class FakeInfoProvider: DisplayInfoProviding {
    var online: [CGDirectDisplayID: Bool] = [:] // id -> isBuiltin
    var active: Set<CGDirectDisplayID>?

    func onlineDisplayIDs() -> [CGDirectDisplayID] { Array(online.keys) }
    func activeDisplayIDs() -> [CGDirectDisplayID] { Array(active ?? Set(online.keys)) }
    func isBuiltin(_ id: CGDirectDisplayID) -> Bool { online[id] ?? false }
}

private final class FakeIDStore: DisplayIDPersisting {
    var storedID: CGDirectDisplayID?
    var storedOffState = false
    var storedAutoRevert = true
    func save(_ id: CGDirectDisplayID) { storedID = id }
    func load() -> CGDirectDisplayID? { storedID }
    func saveOffState(_ isOff: Bool) { storedOffState = isOff }
    func loadOffState() -> Bool { storedOffState }
    func saveAutoRevertOnReconnect(_ enabled: Bool) { storedAutoRevert = enabled }
    func loadAutoRevertOnReconnect() -> Bool { storedAutoRevert }
}

private final class FakeTouchBarRecovery: TouchBarRecovering, @unchecked Sendable {
    var nudgeCallCount = 0
    /// When true, defers `completion` instead of calling it inline, so tests
    /// can observe state between the nudge starting and finishing — mirrors
    /// the real implementation's async sleep/wake cycle.
    var deferCompletion = false
    var pendingCompletion: (@Sendable () -> Void)?

    func nudge(completion: @escaping @Sendable () -> Void) {
        nudgeCallCount += 1
        if deferCompletion {
            pendingCompletion = completion
        } else {
            completion()
        }
    }
}

@MainActor
final class DisplayStateViewModelTests {
    private let configurer = FakeConfigurer()
    private let infoProvider = FakeInfoProvider()
    private let idStore = FakeIDStore()
    private let touchBarRecovery = FakeTouchBarRecovery()
    private let assertionManager = FakeAssertionManager()

    private func makeViewModel() -> DisplayStateViewModel {
        let manager = DisplayManager(configurer: configurer, infoProvider: infoProvider, idStore: idStore)
        let stayAwake = StayAwake(
            defaults: UserDefaults(suiteName: "DisplayStateViewModelTests-\(UUID().uuidString)")!,
            assertionManager: assertionManager
        )
        return DisplayStateViewModel(manager: manager, touchBarRecovery: touchBarRecovery, stayAwake: stayAwake)
    }

    @Test func toggleFromOffToOnNudgesTouchBar() {
        infoProvider.online = [1: true, 2: false]
        idStore.storedID = 1
        idStore.storedOffState = true // starts off

        let viewModel = makeViewModel()
        viewModel.toggle() // off -> on

        #expect(viewModel.isInternalDisplayOff == false)
        #expect(touchBarRecovery.nudgeCallCount == 1)
    }

    @Test func toggleFromOnToOffDoesNotNudge() {
        infoProvider.online = [1: true, 2: false]
        idStore.storedOffState = false // starts on

        let viewModel = makeViewModel()
        viewModel.toggle() // on -> off

        #expect(viewModel.isInternalDisplayOff == true)
        #expect(touchBarRecovery.nudgeCallCount == 0)
    }

    @Test func toggleThatFailsToEnableDoesNotNudge() {
        // Off before toggle, but no cached display ID anywhere — enable fails,
        // so the display never actually transitions off -> on.
        idStore.storedID = nil
        idStore.storedOffState = true

        let viewModel = makeViewModel()
        viewModel.toggle()

        #expect(viewModel.isInternalDisplayOff == true) // still off, enable failed
        #expect(touchBarRecovery.nudgeCallCount == 0)
    }

    @Test func setBlackoutActiveIsIntentBasedAndIdempotent() {
        infoProvider.online = [1: true, 2: false]
        idStore.storedOffState = false // starts on

        let viewModel = makeViewModel()

        viewModel.setBlackoutActive(false) // already inactive — no work
        #expect(viewModel.isInternalDisplayOff == false)
        #expect(touchBarRecovery.nudgeCallCount == 0)

        viewModel.setBlackoutActive(true)
        #expect(viewModel.isInternalDisplayOff == true)

        viewModel.setBlackoutActive(true) // already active — no work
        #expect(viewModel.isInternalDisplayOff == true)

        viewModel.setBlackoutActive(false)
        #expect(viewModel.isInternalDisplayOff == false)
        #expect(touchBarRecovery.nudgeCallCount == 1)
    }

    @Test func blackoutSwitchBindingMatchesStateNotItsInverse() {
        infoProvider.online = [1: true, 2: false]
        idStore.storedOffState = false // starts on
        let viewModel = makeViewModel()
        let view = MenuBarView(viewModel: viewModel)

        #expect(view.toggleBinding.wrappedValue == false)

        view.toggleBinding.wrappedValue = true
        #expect(viewModel.isInternalDisplayOff == true)
        #expect(view.toggleBinding.wrappedValue == true)

        view.toggleBinding.wrappedValue = false
        #expect(viewModel.isInternalDisplayOff == false)
        #expect(view.toggleBinding.wrappedValue == false)
    }

    @Test func stayAwakeEnabledTogglesThePowerAssertion() {
        infoProvider.online = [1: true, 2: false]
        idStore.storedOffState = false
        let viewModel = makeViewModel()

        #expect(viewModel.stayAwakeEnabled == false)

        viewModel.stayAwakeEnabled = true
        #expect(assertionManager.acquireCallCount == 1)

        viewModel.stayAwakeEnabled = false
        #expect(assertionManager.releaseCallCount == 1)
    }

    @Test func toggleSuspendsStayAwakeAssertionDuringTouchBarNudge() {
        infoProvider.online = [1: true, 2: false]
        idStore.storedID = 1
        idStore.storedOffState = true // starts off

        let viewModel = makeViewModel()
        viewModel.stayAwakeEnabled = true
        touchBarRecovery.deferCompletion = true
        #expect(assertionManager.acquireCallCount == 1)

        viewModel.toggle() // off -> on, nudges the Touch Bar

        // While the nudge's sleep/wake cycle is in flight, the assertion must
        // be released so macOS doesn't fight the forced display sleep.
        #expect(assertionManager.releaseCallCount == 1)
        #expect(assertionManager.acquireCallCount == 1)

        touchBarRecovery.pendingCompletion?()

        // Once the cycle finishes, Stay Awake resumes.
        #expect(assertionManager.acquireCallCount == 2)
    }

    @Test func toggleDoesNotTouchStayAwakeAssertionWhenDisabled() {
        infoProvider.online = [1: true, 2: false]
        idStore.storedID = 1
        idStore.storedOffState = true // starts off

        let viewModel = makeViewModel()
        #expect(viewModel.stayAwakeEnabled == false)

        viewModel.toggle() // off -> on

        #expect(assertionManager.acquireCallCount == 0)
        #expect(assertionManager.releaseCallCount == 0)
    }

    @Test func hasExternalDisplayIgnoresNonDrawableExternal() {
        // A stale/ghost entry in the online list must not enable the switch:
        // the app can't black out the internal panel for a display it can't
        // prove is drawable.
        infoProvider.online = [1: true, 2: false]
        infoProvider.active = [1]

        let viewModel = makeViewModel()

        #expect(viewModel.hasExternalDisplay == false)
    }
}
